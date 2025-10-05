// lib/dashboard/bloc/organization_bloc.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:bloc/bloc.dart'; // ✅ Sửa lỗi import
import 'package:flutter/services.dart';
import 'package:web3dart/web3dart.dart';

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

  OrganizationBloc({required this.web3client, required this.credentials})
    : super(OrganizationInitial()) {
    on<FetchOrganizationDetails>(_onFetchDetails);
    on<AddMemberToOrganization>(_onAddMember);
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
    // Chức năng này không có trong Users.sol, bạn cần thêm vào nếu muốn sử dụng
    // _addMemberFunction = deployedContract.function('addAssociateToOrganization');

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

    // Dựa trên struct UserDetails trong Types.sol:
    final BigInt role = userStruct[2] as BigInt;
    final bool inOrg = userStruct[3] as bool;

    // Chỉ người có vai trò "Manufacturer" (giá trị 1) và đã ở trong một tổ chức mới được coi là Owner.
    if (role.toInt() != 1 || !inOrg) {
      throw Exception(
        "❌ Tài khoản này không phải là chủ sở hữu của một tổ chức.",
      );
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
    emit(OrganizationLoading());
    try {
      await _initializeContract();
      await _checkIsOrganizationOwner();

      // Gọi hàm getOrganization từ contract
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

      // Kiểm tra trường ownerAddress (index 2) để xem có phải địa chỉ rỗng không
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
      emit(OrganizationError(e.toString()));
    }
  }

  /// Xử lý sự kiện thêm thành viên mới
  Future<void> _onAddMember(
    AddMemberToOrganization event,
    Emitter<OrganizationState> emit,
  ) async {
    emit(
      OrganizationError(
        "⚠️ Chức năng thêm thành viên chưa được triển khai trên Smart Contract.",
      ),
    );
    // try {
    //   await _initializeContract();
    //   await _checkIsOrganizationOwner();

    //   final memberAddr = EthereumAddress.fromHex(event.memberAddress);

    //   final txHash = await web3client.sendTransaction(
    //     credentials,
    //     Transaction.callContract(
    //       contract: deployedContract,
    //       function: _addMemberFunction,
    //       parameters: [memberAddr],
    //     ),
    //     chainId: 1337,
    //   );

    //   developer.log("✅ [OrgBloc] Giao dịch thêm thành viên đã được gửi: tx=$txHash");
    //   emit(OrganizationActionSuccess("Yêu cầu thêm thành viên đã được gửi. Vui lòng chờ xác nhận."));

    //   await Future.delayed(const Duration(seconds: 2));
    //   add(FetchOrganizationDetails());

    // } catch (e) {
    //   developer.log("❌ [OrgBloc] Lỗi khi thêm thành viên:", error: e);
    //   emit(OrganizationError("Lỗi khi thêm thành viên: ${e.toString()}"));
    // }
  }

  /// Xử lý sự kiện xóa thành viên
  Future<void> _onRemoveMember(
    RemoveMemberFromOrganization event,
    Emitter<OrganizationState> emit,
  ) async {
    emit(
      OrganizationError(
        "⚠️ Chức năng xóa thành viên chưa được triển khai trên Smart Contract.",
      ),
    );
  }
}
