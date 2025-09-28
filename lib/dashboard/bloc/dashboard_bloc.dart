// lib/dashboard/bloc/dashboard_bloc.dart
// ignore_for_file: avoid_print

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
      const String rpcUrl = "http://10.0.2.2:7545"; 
      const String privateKey =
          "0xf4e8a077c99a5df3439ecb039b70984c507c842e3deef53aa08cacebcd728d0f"; 

      _web3client = Web3Client(rpcUrl, http.Client());

      final String abiString = await rootBundle.loadString(
        "build/contracts/Chain.json",
      );
      final jsonAbi = jsonDecode(abiString);

      final abi = ContractAbi.fromJson(jsonEncode(jsonAbi['abi']), 'Chain');

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
      final txHash = await _web3client.sendTransaction(
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
        chainId: 5777, 
      );

      emit(DashboardSuccessState("Product created! TxHash: $txHash"));
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
