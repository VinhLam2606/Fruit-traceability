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

  late ContractFunction _transferProductFunction;
  late ContractFunction _getOrganizationOwnerFunction;

  List<Product> _currentProducts = [];

  DashboardBloc({required this.web3client, required this.credentials})
    : super(DashboardInitial()) {
    on<DashboardInitialFetchEvent>(_dashboardInitialFetchEvent);
    on<CreateProductButtonPressedEvent>(_createProductButtonPressedEvent);
    on<FetchProductsEvent>(_fetchProductsEvent);
    on<TransferProductEvent>(_transferProductEvent);
  }

  // --- HÀM KHỞI TẠO (KHÔNG ĐỔI) ---
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
      emit(
        DashboardErrorState(
          "Lỗi khởi tạo: ${e.toString()}",
          products: _currentProducts,
        ),
      );
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
  // --- KẾT THÚC HÀM KHỞI TẠO ---

  // ✅ HÀM HELPER MỚI: Gửi và chờ xác nhận
  Future<TransactionReceipt> _sendAndWaitForReceipt(
    Transaction transaction,
  ) async {
    final txHash = await web3client.sendTransaction(
      credentials,
      transaction,
      chainId: 1337,
    );

    developer.log(
      "⏳ Transaction submitted. TxHash: $txHash. Waiting for confirmation...",
    );

    TransactionReceipt? receipt;
    int attempts = 0;
    // Chờ tối đa 60 giây
    while (receipt == null && attempts < 60) {
      await Future.delayed(const Duration(seconds: 1));
      try {
        receipt = await web3client.getTransactionReceipt(txHash);
      } catch (e) {
        // Bỏ qua lỗi (ví dụ: "not found" khi giao dịch chưa được mined)
      }
      attempts++;
    }

    if (receipt == null) {
      throw Exception("Transaction timed out. Could not get receipt.");
    }

    if (receipt.status == false) {
      throw Exception("Transaction failed (reverted) on-chain.");
    }

    return receipt;
  }

  FutureOr<void> _createProductButtonPressedEvent(
    CreateProductButtonPressedEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoadingState(products: _currentProducts));
    try {
      final transaction = Transaction.callContract(
        contract: deployedContract,
        function: _addProductFunction,
        parameters: [
          event.batchId,
          event.name,
          BigInt.from(event.date),
          event.seedVariety,
          event.origin,
        ],
      );

      // ✅ SỬA: Chờ giao dịch được xác nhận (Fix Nonce)
      final receipt = await _sendAndWaitForReceipt(transaction);

      developer.log("✅ Product created! TxHash: ${receipt.transactionHash}");
      emit(
        DashboardSuccessState("✅ Product created!", products: _currentProducts),
      );

      // ✅ SỬA: Báo cho UI biết là đã xong
      event.completer?.complete(true);
    } catch (e, st) {
      developer.log("❌ [CreateProduct] Failed", error: e, stackTrace: st);
      emit(
        DashboardErrorState(
          "❌ Failed to create product: $e",
          products: _currentProducts,
        ),
      );

      // ✅ SỬA: Báo cho UI biết là đã lỗi
      event.completer?.complete(false);
    }
  }

  FutureOr<void> _transferProductEvent(
    TransferProductEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoadingState(products: _currentProducts));
    try {
      final ownerResult = await web3client.call(
        contract: deployedContract,
        function: _getOrganizationOwnerFunction,
        params: [event.receiverOrganizationId],
      );

      final receiverAddress = ownerResult[0] as EthereumAddress;

      if (receiverAddress.hex == "0x0000000000000000000000000000000000000000") {
        throw Exception(
          "Không tìm thấy tổ chức với ID '${event.receiverOrganizationId}'.",
        );
      }

      final transaction = Transaction.callContract(
        contract: deployedContract,
        function: _transferProductFunction,
        parameters: [event.batchId, receiverAddress],
      );

      // ✅ SỬA: Chờ giao dịch được xác nhận (Fix Nonce)
      final receipt = await _sendAndWaitForReceipt(transaction);

      developer.log(
        "✅ Product transferred! TxHash: ${receipt.transactionHash}",
      );
      emit(
        DashboardSuccessState(
          "✅ Chuyển giao sản phẩm thành công!",
          products: _currentProducts,
        ),
      );

      // ✅ SỬA: Báo cho UI biết là đã xong
      event.completer?.complete(true);

      add(FetchProductsEvent());
    } catch (e, st) {
      developer.log("❌ [TransferProduct] Failed", error: e, stackTrace: st);
      emit(
        DashboardErrorState(
          "❌ Lỗi khi chuyển giao sản phẩm: $e",
          products: _currentProducts,
        ),
      );
      // ✅ SỬA: Báo cho UI biết là đã lỗi
      event.completer?.complete(false);
    }
  }

  // --- HÀM FETCH (KHÔNG ĐỔI) ---
  FutureOr<void> _fetchProductsEvent(
    FetchProductsEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoadingState(products: _currentProducts));
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

      _currentProducts = products;

      developer.log("✅ Loaded ${products.length} products.");
      emit(ProductsLoadedState(products));
    } catch (e, st) {
      developer.log("❌ [FetchProducts] Failed", error: e, stackTrace: st);
      emit(
        DashboardErrorState(
          "❌ Failed to load products: $e",
          products: _currentProducts,
        ),
      );
    }
  }
}
