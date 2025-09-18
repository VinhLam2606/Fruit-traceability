// dashboard/bloc/dashboard_bloc.dart
import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:untitled/dashboard/model/product.dart';
import 'package:web3dart/web3dart.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc() : super(DashboardInitial()) {
    on<DashboardInitialFetchEvent>(_dashboardInitialFetchEvent);
    on<CreateProductButtonPressedEvent>(_createProductButtonPressedEvent);
    on<FetchProductsEvent>(_fetchProductsEvent);
  }

  late Web3Client _web3client;
  late DeployedContract _deployedContract;
  late EthPrivateKey _credentials;

  late ContractFunction _addProductFunction;
  late ContractFunction _getAllProductsFunction;

  FutureOr<void> _dashboardInitialFetchEvent(
    DashboardInitialFetchEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoadingState());
    try {
      // RPC cho Android Emulator (10.0.2.2) hoặc 127.0.0.1 nếu chạy trực tiếp
      const String rpcUrl = "http://10.0.2.2:7545";
      const String privateKey =
          "0x641461d541be24b36b695139db922915c1849c6f178e0e771bbd95dce037c3eb";

      _web3client = Web3Client(rpcUrl, http.Client());

      final String abiString = await rootBundle.loadString(
        "build/contracts/Chain.json",
      );
      final jsonAbi = jsonDecode(abiString);

      final abi = ContractAbi.fromJson(jsonEncode(jsonAbi['abi']), 'Chain');

      // Lấy networkId động (1337 hoặc 5777 tuỳ Ganache)
      final networks = jsonAbi['networks'] as Map<String, dynamic>;
      if (networks.isEmpty) {
        throw Exception(
          "No deployed network found in ABI. Did you run migrate?",
        );
      }
      final networkKey = networks.keys.first;
      final contractAddress = EthereumAddress.fromHex(
        networks[networkKey]['address'],
      );

      _credentials = EthPrivateKey.fromHex(privateKey);
      _deployedContract = DeployedContract(abi, contractAddress);

      _addProductFunction = _deployedContract.function('addAProduct');
      _getAllProductsFunction = _deployedContract.function('getAllProducts');

      emit(DashboardInitialSuccessState());
    } catch (e) {
      emit(DashboardErrorState("Initialization failed: ${e.toString()}"));
    }
  }

  FutureOr<void> _createProductButtonPressedEvent(
    CreateProductButtonPressedEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoadingState());
    try {
      final result = await _web3client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _deployedContract,
          function: _addProductFunction,
          parameters: [
            event.batchId,
            event.name,
            BigInt.from(event.harvestDate),
            BigInt.from(event.expiryDate),
          ],
        ),
        chainId: 1337, // đổi thành 5777 nếu Ganache GUI
      );

      emit(
        DashboardSuccessState("Product created successfully! TxHash: $result"),
      );
    } catch (e) {
      emit(DashboardErrorState("Failed to create product: ${e.toString()}"));
    }
  }

  FutureOr<void> _fetchProductsEvent(
    FetchProductsEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoadingState());
    try {
      final result = await _web3client.call(
        contract: _deployedContract,
        function: _getAllProductsFunction,
        params: [],
      );

      final List<dynamic> productListFromContract = result[0];
      final List<Product> products = productListFromContract
          .map((p) => Product.fromContract(p as List<dynamic>))
          .toList();

      emit(ProductsLoadedState(products));
    } catch (e) {
      emit(DashboardErrorState("Failed to load products: ${e.toString()}"));
    }
  }
}
