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

  DashboardBloc({required this.web3client, required this.credentials})
    : super(DashboardInitial()) {
    on<DashboardInitialFetchEvent>(_dashboardInitialFetchEvent);
    on<CreateProductButtonPressedEvent>(_createProductButtonPressedEvent);
    on<FetchProductsEvent>(_fetchProductsEvent);
  }

  FutureOr<void> _dashboardInitialFetchEvent(
    DashboardInitialFetchEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoadingState());
    try {
      final address = credentials.address;
      developer.log("🔓 [Init] Public address: ${address.hex}");

      // Kiểm tra số dư ví (để đảm bảo tx hợp lệ)
      final balance = await web3client.getBalance(address);
      developer.log(
        "💰 Balance: ${balance.getValueInUnit(EtherUnit.ether)} ETH",
      );

      // --- Load ABI ---
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

      // --- Map hàm Solidity ---
      _addProductFunction = deployedContract.function('addAProduct');
      _getProductsByUserFunction = deployedContract.function(
        'getProductsByUser',
      );
      _isRegisteredFunction = deployedContract.function('isRegisteredAuth');
      _getUserFunction = deployedContract.function('getUser');

      // --- Kiểm tra role ---
      await _checkManufacturer(address);

      emit(DashboardInitialSuccessState());
      add(FetchProductsEvent());
    } catch (e, st) {
      developer.log("❌ [Init] DashboardBloc error", error: e, stackTrace: st);
      emit(DashboardErrorState("Lỗi khởi tạo: ${e.toString()}"));
    }
  }

  Future<void> _checkManufacturer(EthereumAddress address) async {
    // 1️⃣ Kiểm tra đã register chưa
    final isRegisteredResult = await web3client.call(
      contract: deployedContract,
      function: _isRegisteredFunction,
      params: [address],
    );

    final isRegistered = isRegisteredResult[0] as bool;
    if (!isRegistered) {
      throw Exception("❌ User chưa được register → cần đăng ký trước.");
    }

    // 2️⃣ Lấy thông tin user struct
    final userData = await web3client.call(
      contract: deployedContract,
      function: _getUserFunction,
      params: [address],
    );

    if (userData.isEmpty || userData[0] == null) {
      throw Exception("❌ Không lấy được dữ liệu user từ blockchain.");
    }

    // ⚡ Sửa điểm lỗi ở đây
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
          parameters: [event.batchId, event.name, BigInt.from(event.date)],
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
