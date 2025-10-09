// lib/dashboard/bloc/organization_bloc.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:web3dart/web3dart.dart';

import '../../../auth/service/auth_service.dart';
import '../model/organization.dart';

part 'organization_event.dart';
part 'organization_state.dart';

class OrganizationBloc extends Bloc<OrganizationEvent, OrganizationState> {
  final Web3Client web3client;
  final EthPrivateKey credentials;

  late DeployedContract deployedContract;
  bool _isContractLoaded = false;

  // Khai báo các hàm trong Smart Contract sẽ sử dụng
  late ContractFunction _getUserFunction;
  late ContractFunction _getOrganizationFunction;
  late ContractFunction _addMemberFunction;
  late ContractFunction _isRegisteredFunction;
  // 🟢 KHAI BÁO HÀM XÓA MỚI (Từ Users.sol: removeAssociateFromOrganization)
  late ContractFunction _removeMemberFunction;

  OrganizationBloc({required this.web3client, required this.credentials})
    : super(OrganizationInitial()) {
    on<FetchOrganizationDetails>(_onFetchDetails);
    on<AddMemberToOrganization>(_onAddMember);
    on<AddMemberByEmail>(_onAddMemberByEmail);
    on<RemoveMemberFromOrganization>(_onRemoveMember);
  }

  /// Khởi tạo contract, load ABI và map các hàm cần thiết.
  Future<void> _initializeContract() async {
    if (_isContractLoaded) return;

    final abiString = await rootBundle.loadString("build/contracts/Chain.json");
    final jsonAbi = jsonDecode(abiString);

    if (!jsonAbi.containsKey('abi') || !jsonAbi.containsKey('networks')) {
      throw Exception("❌ Lỗi file ABI: Thiếu 'abi' hoặc 'networks'.");
    }

    final abi = ContractAbi.fromJson(jsonEncode(jsonAbi['abi']), 'Chain');
    final networks = jsonAbi['networks'] as Map<String, dynamic>;

    if (networks.isEmpty) {
      throw Exception(
        "❌ Lỗi file ABI: Không tìm thấy network. Bạn đã deploy contract và copy file JSON mới chưa?",
      );
    }

    final networkKey = networks.keys.first;
    final contractAddressHex = networks[networkKey]['address'] as String?;
    if (contractAddressHex == null || contractAddressHex.isEmpty) {
      throw Exception("❌ Lỗi file ABI: Không tìm thấy địa chỉ contract.");
    }

    final contractAddress = EthereumAddress.fromHex(contractAddressHex);
    deployedContract = DeployedContract(abi, contractAddress);
    developer.log("📌 [OrgBloc] Contract đã được load tại: $contractAddress");

    _getUserFunction = deployedContract.function('getUser');
    _isRegisteredFunction = deployedContract.function('isRegisteredAuth');
    _getOrganizationFunction = deployedContract.function('getOrganization');
    _addMemberFunction = deployedContract.function(
      'addAssociateToOrganization',
    );
    // 🟢 ÁNH XẠ HÀM XÓA MỚI
    _removeMemberFunction = deployedContract.function(
      'removeAssociateFromOrganization',
    );

    _isContractLoaded = true;
  }

  /// Kiểm tra xem user hiện tại có phải là chủ sở hữu tổ chức hay không.
  Future<void> _checkIsOrganizationOwner() async {
    final address = credentials.address;

    final isRegisteredResult = await web3client.call(
      contract: deployedContract,
      function: _isRegisteredFunction,
      params: [address],
    );
    if (isRegisteredResult.isEmpty || !(isRegisteredResult.first as bool)) {
      throw Exception("❌ Tài khoản chưa được đăng ký.");
    }

    final userData = await web3client.call(
      contract: deployedContract,
      function: _getUserFunction,
      params: [address],
    );

    if (userData.isEmpty) {
      throw Exception("❌ Không lấy được dữ liệu người dùng từ blockchain.");
    }

    final userStruct = userData.first as List<dynamic>;
    final BigInt role = userStruct[2] as BigInt;
    final bool inOrg = userStruct[3] as bool;

    if (role.toInt() != 1 || !inOrg) {
      throw Exception("❌ Tài khoản này không phải là chủ sở hữu tổ chức.");
    }

    developer.log(
      "✅ [OrgBloc] Xác thực thành công: User là một Organization Owner.",
    );
  }

  /// Xử lý sự kiện fetch chi tiết tổ chức
  Future<void> _onFetchDetails(
    FetchOrganizationDetails event,
    Emitter<OrganizationState> emit,
  ) async {
    // ⚠️ Sửa lỗi: Nếu đang ở state OrganizationLoaded, không cần emit Loading state
    // trước khi gọi check owner, nhưng ta giữ emit Loading để chỉ ra rằng dữ liệu đang được tải lại.
    emit(OrganizationLoading());
    try {
      await _initializeContract();
      await _checkIsOrganizationOwner();

      final result = await web3client.call(
        contract: deployedContract,
        function: _getOrganizationFunction,
        params: [credentials.address],
      );

      if (result.isEmpty || result.first is! List<dynamic>) {
        emit(OrganizationError("❌ Dữ liệu trả về từ contract không hợp lệ."));
        return;
      }

      final rawOrg = result.first as List<dynamic>;
      final EthereumAddress ownerAddress = rawOrg[2] as EthereumAddress;
      const zeroAddress = "0x0000000000000000000000000000000000000000";

      if (ownerAddress.hex.toLowerCase() == zeroAddress) {
        emit(
          OrganizationError(
            "❌ Không tìm thấy dữ liệu Organization cho tài khoản này.",
          ),
        );
        return;
      }

      final org = Organization.fromContract(rawOrg);
      developer.log(
        "✅ [OrgBloc] Đã tải xong thông tin tổ chức: ${org.organizationName}",
      );
      emit(OrganizationLoaded(org));
    } catch (e) {
      developer.log("❌ [OrgBloc] Lỗi khi fetch chi tiết:", error: e);
      // Khi lỗi, nếu trước đó là OrganizationLoaded, ta có thể muốn giữ lại dữ liệu cũ
      // (cần thêm logic copyWith vào OrganizationLoaded state - hiện chưa có)
      // Tạm thời chỉ emit lỗi
      emit(OrganizationError(e.toString()));
    }
  }

  /// Xử lý sự kiện thêm thành viên mới (qua địa chỉ ví)
  Future<void> _onAddMember(
    AddMemberToOrganization event,
    Emitter<OrganizationState> emit,
  ) async {
    // 🟢 Sửa lỗi Refresh: Không emit Loading ngay, giữ trạng thái cũ
    final currentState = state;
    if (currentState is OrganizationLoaded) {
      // Giữ dữ liệu cũ trong khi chờ giao dịch
      // Lưu ý: Nếu muốn thêm indicator loading mà không mất dữ liệu,
      // cần logic copyWith trong OrganizationLoaded state
      // Tạm thời chỉ giữ emit Loading cho tới khi có logic copyWith
      emit(OrganizationLoading());
    } else {
      emit(OrganizationLoading());
    }

    try {
      await _initializeContract();
      await _checkIsOrganizationOwner();

      final memberAddr = EthereumAddress.fromHex(event.memberAddress);

      final isRegisteredResult = await web3client.call(
        contract: deployedContract,
        function: _isRegisteredFunction,
        params: [memberAddr],
      );

      if (isRegisteredResult.isEmpty || !(isRegisteredResult.first as bool)) {
        emit(OrganizationError("❌ Thành viên này chưa đăng ký tài khoản."));
        return;
      }

      final userData = await web3client.call(
        contract: deployedContract,
        function: _getUserFunction,
        params: [memberAddr],
      );

      if (userData.isEmpty) {
        emit(OrganizationError("❌ Không tìm thấy dữ liệu người dùng này."));
        return;
      }

      final userStruct = userData.first as List<dynamic>;
      final bool alreadyInOrg = userStruct[3] as bool;

      if (alreadyInOrg) {
        emit(
          OrganizationError("⚠️ Thành viên này đã thuộc về một tổ chức khác."),
        );
        return;
      }

      final txHash = await web3client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: deployedContract,
          function: _addMemberFunction,
          parameters: [memberAddr],
        ),
        chainId: 1337,
      );

      developer.log("✅ [OrgBloc] Giao dịch thêm thành viên đã gửi: $txHash");
      emit(OrganizationActionSuccess("✅ Đã gửi yêu cầu thêm thành viên."));
      // ⚠️ Đã loại bỏ Future.delayed và add(FetchOrganizationDetails()), UI sẽ tự xử lý refresh.
    } catch (e) {
      developer.log("❌ [OrgBloc] Lỗi khi thêm thành viên:", error: e);
      emit(OrganizationError("Lỗi khi thêm thành viên: ${e.toString()}"));
    }
  }

  /// ✅ Xử lý sự kiện thêm thành viên qua email
  Future<void> _onAddMemberByEmail(
    AddMemberByEmail event,
    Emitter<OrganizationState> emit,
  ) async {
    // 🟢 Sửa lỗi Refresh: Không emit Loading ngay, giữ trạng thái cũ
    final currentState = state;
    if (currentState is OrganizationLoaded) {
      emit(OrganizationLoaded(currentState.organization)); // Giữ trạng thái cũ
    } else {
      emit(OrganizationLoading());
    }

    try {
      final auth = authService.value;
      final targetUser = await auth.getUserWalletByEmail(event.email);

      if (targetUser == null) {
        emit(
          OrganizationError("❌ Không tìm thấy user với email: ${event.email}"),
        );
        return;
      }

      final memberAddress = targetUser['eth_address']!;
      final username = targetUser['username'];
      developer.log(
        "📬 [OrgBloc] Chuẩn bị thêm user $username ($memberAddress) vào tổ chức",
      );

      // Chuyển sang sự kiện thêm thành viên (nó sẽ tự emit OrganizationActionSuccess)
      add(AddMemberToOrganization(memberAddress));
    } catch (e) {
      developer.log(
        "❌ [OrgBloc] Lỗi khi thêm thành viên bằng email:",
        error: e,
      );
      emit(
        OrganizationError(
          "Lỗi khi thêm thành viên bằng email: ${e.toString()}",
        ),
      );
    }
  }

  /// 🟢 Xử lý sự kiện xóa thành viên (Owner removes Associate)
  Future<void> _onRemoveMember(
    RemoveMemberFromOrganization event,
    Emitter<OrganizationState> emit,
  ) async {
    // ⚠️ Đảm bảo không bị mất OrganizationLoaded state khi gọi remove member
    final currentState = state;
    if (currentState is OrganizationLoaded) {
      emit(OrganizationLoaded(currentState.organization)); // Giữ trạng thái cũ
    } else {
      emit(OrganizationLoading());
    }

    try {
      await _initializeContract();
      await _checkIsOrganizationOwner(); // Chỉ owner mới có quyền xóa

      final associateAddress = EthereumAddress.fromHex(event.memberAddress);

      final txHash = await web3client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: deployedContract,
          function: _removeMemberFunction, // 🟢 GỌI HÀM XÓA DÀNH CHO OWNER
          parameters: [associateAddress],
        ),
        chainId: 1337,
      );

      developer.log("✅ [OrgBloc] Giao dịch xóa thành viên đã gửi: $txHash");
      emit(OrganizationActionSuccess("✅ Đã xóa thành viên thành công."));
    } catch (e) {
      developer.log("❌ [OrgBloc] Lỗi khi xóa thành viên:", error: e);
      emit(OrganizationError("Lỗi khi xóa thành viên: ${e.toString()}"));
    }
  }
}
