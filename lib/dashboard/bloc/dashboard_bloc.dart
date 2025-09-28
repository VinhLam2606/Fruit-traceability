// dashboard/bloc/dashboard_bloc.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

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
    on<RegisterOrgAndCreateProductEvent>(_registerOrgAndCreateProductEvent);
  }

  // THAY ĐỔI: Chuyển các biến này thành public (bỏ dấu "_")
  late Web3Client web3client;
  late DeployedContract deployedContract;
  late EthPrivateKey credentials;

  // Contract functions có thể giữ private
  late ContractFunction _addProductFunction;
  late ContractFunction _addOrganizationFunction;
  late ContractFunction _getProductsByUserFunction;
  late ContractFunction _addUserFunction;
  late ContractFunction _isRegisteredFunction;
  late ContractFunction _isOrganizationExistsFunction;

  FutureOr<void> _dashboardInitialFetchEvent(
    DashboardInitialFetchEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoadingState());
    try {
      const String rpcUrl = "http://10.0.2.2:7545";
      const String privateKey =
          "0x711bbb0e6ebee139851b775e6e3616e435d3a7723aafb6fa5c58df1a69ba659a"; // THAY BẰNG PRIVATE KEY CỦA BẠN

      web3client = Web3Client(rpcUrl, http.Client());

      final String abiString = await rootBundle.loadString(
        "build/contracts/Chain.json",
      );
      final jsonAbi = jsonDecode(abiString);
      final abi = ContractAbi.fromJson(jsonEncode(jsonAbi['abi']), 'Chain');
      final networkKey =
          (jsonAbi['networks'] as Map<String, dynamic>).keys.first;
      final contractAddress = EthereumAddress.fromHex(
        jsonAbi['networks'][networkKey]['address'],
      );

      credentials = EthPrivateKey.fromHex(privateKey);
      deployedContract = DeployedContract(abi, contractAddress);

      _addProductFunction = deployedContract.function('addAProduct');
      _addOrganizationFunction = deployedContract.function('addOrganization');
      _getProductsByUserFunction = deployedContract.function(
        'getProductsByUser',
      );
      _addUserFunction = deployedContract.function('addUserThroughAddress');
      _isRegisteredFunction = deployedContract.function('isRegistered');
      _isOrganizationExistsFunction = deployedContract.function(
        'isOrganizationExists',
      );

      final orgName = "Org_${(await credentials.extractAddress()).hex}";
      await _ensureUserAndOrgRegistered(orgName);

      emit(DashboardInitialSuccessState());
      add(FetchProductsEvent());
    } catch (e) {
      emit(DashboardErrorState("Initialization failed: ${e.toString()}"));
    }
  }

  Future<void> _ensureUserAndOrgRegistered(String orgName) async {
    final address = await credentials.extractAddress();

    final isRegisteredResult = await web3client.call(
      contract: deployedContract,
      function: _isRegisteredFunction,
      params: [address],
    );
    final alreadyRegistered = isRegisteredResult[0] as bool;

    if (!alreadyRegistered) {
      developer.log("DEBUG registering user for $address...");
      await web3client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: deployedContract,
          function: _addUserFunction,
          parameters: [address, "Default Manufacturer", BigInt.from(1)],
        ),
        chainId: 1337,
      );
    } else {
      developer.log("DEBUG user already registered: $address");
    }

    final orgExistsResult = await web3client.call(
      contract: deployedContract,
      function: _isOrganizationExistsFunction,
      params: [orgName],
    );
    final alreadyOrgExists = orgExistsResult[0] as bool;

    if (!alreadyOrgExists) {
      developer.log("DEBUG creating new organization: $orgName");
      await web3client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: deployedContract,
          function: _addOrganizationFunction,
          parameters: [
            orgName,
            BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000),
          ],
        ),
        chainId: 1337,
      );
    } else {
      developer.log("DEBUG organization already exists: $orgName");
    }
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
      emit(
        DashboardSuccessState("Product created successfully! TxHash: $txHash"),
      );
    } catch (e) {
      emit(DashboardErrorState("Failed to create product: ${e.toString()}"));
    }
  }

  FutureOr<void> _registerOrgAndCreateProductEvent(
    RegisterOrgAndCreateProductEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoadingState());
    try {
      await web3client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: deployedContract,
          function: _addOrganizationFunction,
          parameters: [
            event.orgName,
            BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000),
          ],
        ),
        chainId: 1337,
      );

      final txHash = await web3client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: deployedContract,
          function: _addProductFunction,
          parameters: [event.batchId, event.name, BigInt.from(event.date)],
        ),
        chainId: 1337,
      );

      emit(
        DashboardSuccessState(
          "Organization registered & product created! TxHash: $txHash",
        ),
      );
    } catch (e) {
      emit(
        DashboardErrorState(
          "Failed to register org and create product: ${e.toString()}",
        ),
      );
    }
  }

  FutureOr<void> _fetchProductsEvent(
    FetchProductsEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoadingState());
    try {
      final address = await credentials.extractAddress();
      final result = await web3client.call(
        contract: deployedContract,
        function: _getProductsByUserFunction,
        params: [address],
      );

      final raw = result[0];
      final List<Product> products;

      if (raw is List && raw.isEmpty) {
        products = [];
      } else if (raw is List && raw.isNotEmpty && raw.first is List) {
        final List<dynamic> productListFromContract = raw;
        products = productListFromContract
            .map((p) {
              if (p is List && p.length == 6) {
                return Product.fromContract(p);
              } else {
                return null;
              }
            })
            .whereType<Product>()
            .toList();
      } else {
        products = [];
      }
      emit(ProductsLoadedState(products));
    } catch (e) {
      emit(DashboardErrorState("Failed to load products: ${e.toString()}"));
    }
  }
}
