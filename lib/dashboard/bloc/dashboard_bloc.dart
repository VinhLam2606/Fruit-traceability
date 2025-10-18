// lib/dashboard/bloc/dashboard_bloc.dart
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:untitled/dashboard/model/product.dart';
import 'package:web3dart/web3dart.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final Web3Client web3client;
  final EthPrivateKey credentials;

  late DeployedContract deployedContract;

  late ContractFunction _addProductFunction;
  late ContractFunction _getProductsByUserFunction;
  late ContractFunction _isRegisteredFunction;
  late ContractFunction _getUserFunction;

  // Ánh xạ hàm chuyển giao và tra cứu Owner
  late ContractFunction _transferProductFunction;
  late ContractFunction _getOrganizationOwnerFunction;

  DashboardBloc({required this.web3client, required this.credentials})
    : super(DashboardInitial()) {
    on<DashboardInitialFetchEvent>(_dashboardInitialFetchEvent);
    on<CreateProductButtonPressedEvent>(_createProductButtonPressedEvent);
    on<FetchProductsEvent>(_fetchProductsEvent);
    on<TransferProductEvent>(_transferProductEvent);
  }

  // ... (Hàm _dashboardInitialFetchEvent và _checkManufacturer giữ nguyên) ...

  FutureOr<void> _dashboardInitialFetchEvent(
    DashboardInitialFetchEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoadingState());
    try {
      final address = credentials.address;
      developer.log("🔓 [Init] Public address: ${address.hex}");

      final balance = await web3client.getBalance(address);
      developer.log(
        "💰 Balance: ${balance.getValueInUnit(EtherUnit.ether)} ETH",
      );

      final abiString = await rootBundle.loadString(
        "build/contracts/Chain.json",
      );
      final jsonAbi = jsonDecode(abiString);

      if (!jsonAbi.containsKey('abi') || !jsonAbi.containsKey('networks')) {
        throw Exception("❌ ABI file không hợp lệ hoặc thiếu networks.");
      }

      final abi = ContractAbi.fromJson(jsonEncode(jsonAbi['abi']), 'Chain');
      final networks = jsonAbi['networks'] as Map<String, dynamic>;
      if (networks.isEmpty) {
        throw Exception("❌ Không tìm thấy network nào trong Chain.json.");
      }

      final networkKey = networks.keys.first;
      final contractAddressHex = networks[networkKey]['address'] as String?;
      if (contractAddressHex == null || contractAddressHex.isEmpty) {
        throw Exception("❌ Không tìm thấy contract address trong Chain.json.");
      }

      final contractAddress = EthereumAddress.fromHex(contractAddressHex);
      deployedContract = DeployedContract(abi, contractAddress);
      developer.log("📌 Contract address: $contractAddress");

      _addProductFunction = deployedContract.function('addAProduct');
      _getProductsByUserFunction = deployedContract.function(
        'getProductsByUser',
      );
      _isRegisteredFunction = deployedContract.function('isRegisteredAuth');
      _getUserFunction = deployedContract.function('getUser');
      _transferProductFunction = deployedContract.function('transferProduct');
      _getOrganizationOwnerFunction = deployedContract.function(
        'getOrganizationOwner',
      );

      await _checkManufacturer(address);

      emit(DashboardInitialSuccessState());
      add(FetchProductsEvent());
    } catch (e, st) {
      developer.log("❌ [Init] DashboardBloc error", error: e, stackTrace: st);
      emit(DashboardErrorState("Lỗi khởi tạo: ${e.toString()}"));
    }
  }

  Future<void> _checkManufacturer(EthereumAddress address) async {
    final isRegisteredResult = await web3client.call(
      contract: deployedContract,
      function: _isRegisteredFunction,
      params: [address],
    );

    final isRegistered = isRegisteredResult[0] as bool;
    if (!isRegistered) {
      throw Exception("❌ User chưa được register → cần đăng ký trước.");
    }

    final userData = await web3client.call(
      contract: deployedContract,
      function: _getUserFunction,
      params: [address],
    );

    if (userData.isEmpty || userData[0] == null) {
      throw Exception("❌ Không lấy được dữ liệu user từ blockchain.");
    }

    final List<dynamic> userStruct = userData[0] as List<dynamic>;

    if (userStruct.length < 4) {
      throw Exception(
        "❌ Struct trả về không hợp lệ: ${userStruct.length} field.",
      );
    }

    final BigInt role = userStruct[2] as BigInt;
    final bool inOrg = userStruct[3] as bool;

    if (role.toInt() != 1 || !inOrg) {
      throw Exception("❌ User không phải Manufacturer trong Organization.");
    }

    developer.log("✅ User là Manufacturer và thuộc Organization → OK");
  }

  // ==================== 💡 HÀM 1 ĐƯỢC CẬP NHẬT ====================
  FutureOr<void> _createProductButtonPressedEvent(
    CreateProductButtonPressedEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoadingState());
    try {
      final txHash = await web3client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: deployedContract,
          function: _addProductFunction,
          // Cập nhật tham số để khớp với contract
          parameters: [
            event.batchId,
            event.name,
            BigInt.from(event.date),
            event.seedVariety, // Thêm seedVariety
            event.origin, // Thêm origin
          ],
        ),
        chainId: 1337,
      );

      developer.log("✅ Product created! TxHash: $txHash");
      emit(DashboardSuccessState("✅ Product created! TxHash: $txHash"));
    } catch (e, st) {
      developer.log("❌ [CreateProduct] Failed", error: e, stackTrace: st);
      emit(DashboardErrorState("❌ Failed to create product: $e"));
    }
  }

  // ==================== HÀM Chuyển giao (Giữ nguyên) ====================
  FutureOr<void> _transferProductEvent(
    TransferProductEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoadingState());
    try {
      // 1. Tra cứu địa chỉ ví của chủ sở hữu tổ chức nhận
      final ownerResult = await web3client.call(
        contract: deployedContract,
        function: _getOrganizationOwnerFunction,
        params: [event.receiverOrganizationId],
      );

      final receiverAddress = ownerResult[0] as EthereumAddress;

      // Kiểm tra địa chỉ có hợp lệ không (address(0) nếu không tìm thấy)
      if (receiverAddress.hex == "0x0000000000000000000000000000000000000000") {
        // Thay vì throw Exception, emit một lỗi có thông báo rõ ràng
        emit(
          DashboardErrorState(
            "Không tìm thấy tổ chức với ID '${event.receiverOrganizationId}'. Vui lòng kiểm tra lại.",
          ),
        );
        // Dừng hàm tại đây
        return;
      }

      // 2. Gửi giao dịch chuyển giao sản phẩm
      final txHash = await web3client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: deployedContract,
          function: _transferProductFunction,
          parameters: [event.batchId, receiverAddress],
        ),
        chainId: 1337,
      );

      developer.log("✅ Product transferred! TxHash: $txHash");
      emit(DashboardSuccessState("✅ Chuyển giao sản phẩm thành công!"));

      // Sau khi chuyển giao xong, fetch lại danh sách sản phẩm
      add(FetchProductsEvent());
    } catch (e, st) {
      developer.log("❌ [TransferProduct] Failed", error: e, stackTrace: st);
      emit(DashboardErrorState("❌ Lỗi khi chuyển giao sản phẩm: $e"));
    }
  }
  // ===============================================================

  // ==================== 💡 HÀM 2 ĐƯỢC CẬP NHẬT ====================
  Future<void> createProductDirectly({
    required String batchId,
    required String name,
    required int date,
    required String seedVariety, // Thêm tham số
    required String origin, // Thêm tham số
  }) async {
    add(
      CreateProductButtonPressedEvent(
        batchId: batchId,
        name: name,
        date: date,
        seedVariety: seedVariety, // Truyền tham số
        origin: origin, // Truyền tham số
      ),
    );

    await Future.delayed(const Duration(seconds: 10));
  }

  FutureOr<void> _fetchProductsEvent(
    FetchProductsEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoadingState());
    try {
      final address = credentials.address;
      final result = await web3client.call(
        contract: deployedContract,
        function: _getProductsByUserFunction,
        params: [address],
      );

      final raw = result[0];
      final List<Product> products;

      if (raw is List) {
        products = raw
            .map(
              (p) =>
                  (p is List && p.isNotEmpty) ? Product.fromContract(p) : null,
            )
            .whereType<Product>()
            .toList();
      } else {
        products = [];
      }

      developer.log("✅ Loaded ${products.length} products.");
      emit(ProductsLoadedState(products));
    } catch (e, st) {
      developer.log("❌ [FetchProducts] Failed", error: e, stackTrace: st);
      emit(DashboardErrorState("❌ Failed to load products: $e"));
    }
  }
}
