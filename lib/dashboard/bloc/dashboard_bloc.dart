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
  // ... (Constructor và khai báo biến không đổi) ...
  DashboardBloc() : super(DashboardInitial()) {
    developer.log("DEBUG DashboardBloc created");

    on<DashboardInitialFetchEvent>(_dashboardInitialFetchEvent);
    on<CreateProductButtonPressedEvent>(_createProductButtonPressedEvent);
    on<FetchProductsEvent>(_fetchProductsEvent);
    on<RegisterOrgAndCreateProductEvent>(_registerOrgAndCreateProductEvent);
  }

  late Web3Client _web3client;
  late DeployedContract _deployedContract;
  late EthPrivateKey _credentials;

  // Contract functions
  late ContractFunction _addProductFunction;
  late ContractFunction _addOrganizationFunction;
  late ContractFunction _getProductsByUserFunction;
  late ContractFunction _addUserFunction;
  late ContractFunction _isRegisteredFunction;
  late ContractFunction _isOrganizationExistsFunction;

  // ... (Hàm _dashboardInitialFetchEvent và _ensureUserAndOrgRegistered không đổi) ...
  FutureOr<void> _dashboardInitialFetchEvent(
    DashboardInitialFetchEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoadingState());
    try {
      const String rpcUrl = "http://10.0.2.2:7545";
      const String privateKey =
          // Thay bằng private key mới của bạn khi test
          "0x34e80e9b48d31a6e719ee02af8a4e8ebcf7d8fbb4404fa304c67b9c5943d7a08";

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
      _addOrganizationFunction = _deployedContract.function('addOrganization');
      _getProductsByUserFunction = _deployedContract.function(
        'getProductsByUser',
      );
      _addUserFunction = _deployedContract.function('addUserThroughAddress');
      _isRegisteredFunction = _deployedContract.function('isRegistered');
      _isOrganizationExistsFunction = _deployedContract.function(
        'isOrganizationExists',
      );

      developer.log(
        "DEBUG Dashboard initialized with contract at $contractAddress",
      );

      // Đảm bảo user và tổ chức tồn tại một lần duy nhất
      final orgName = "Org_${(await _credentials.extractAddress()).hex}";
      await _ensureUserAndOrgRegistered(orgName);

      emit(DashboardInitialSuccessState());
    } catch (e) {
      emit(DashboardErrorState("Initialization failed: ${e.toString()}"));
    }
  }

  Future<void> _ensureUserAndOrgRegistered(String orgName) async {
    final address = await _credentials.extractAddress();

    // 1. Check user đã tồn tại chưa
    final isRegisteredResult = await _web3client.call(
      contract: _deployedContract,
      function: _isRegisteredFunction,
      params: [address],
    );
    final alreadyRegistered = isRegisteredResult[0] as bool;

    if (!alreadyRegistered) {
      developer.log("DEBUG registering user for $address...");
      await _web3client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _deployedContract,
          function: _addUserFunction,
          parameters: [
            address,
            "Default Manufacturer",
            BigInt.from(1),
          ], // 1 = Manufacturer
        ),
        chainId: 1337,
      );
    } else {
      developer.log("DEBUG user already registered: $address");
    }

    // 2. Check tổ chức đã tồn tại chưa
    final orgExistsResult = await _web3client.call(
      contract: _deployedContract,
      function: _isOrganizationExistsFunction,
      params: [orgName],
    );
    final alreadyOrgExists = orgExistsResult[0] as bool;

    if (!alreadyOrgExists) {
      developer.log("DEBUG creating new organization: $orgName");
      await _web3client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _deployedContract,
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
      developer.log("DEBUG creating product: ${event.name}");
      developer.log("DEBUG calling addAProduct...");

      final txHash = await _web3client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _deployedContract,
          function: _addProductFunction,
          // THAY ĐỔI: Cập nhật tham số truyền vào contract
          parameters: [
            event.batchId,
            event.name,
            BigInt.from(event.date), // Chỉ truyền một tham số date
          ],
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

  // ... (Hàm _registerOrgAndCreateProductEvent tương tự, cần cập nhật parameters) ...
  FutureOr<void> _registerOrgAndCreateProductEvent(
    RegisterOrgAndCreateProductEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoadingState());
    try {
      developer.log("DEBUG registering org: ${event.orgName}");

      // Tách biệt việc đăng ký tổ chức.
      await _web3client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _deployedContract,
          function: _addOrganizationFunction,
          parameters: [
            event.orgName,
            BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000),
          ],
        ),
        chainId: 1337,
      );

      developer.log("DEBUG Organization registered. Now creating product...");

      final txHash = await _web3client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _deployedContract,
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
      developer.log("DEBUG fetching products...");

      final address = await _credentials.extractAddress();
      final result = await _web3client.call(
        contract: _deployedContract,
        function: _getProductsByUserFunction,
        params: [address],
      );

      developer.log("DEBUG getProductsByUser raw result: $result");

      final raw = result[0];
      final List<Product> products;

      if (raw is List && raw.isEmpty) {
        products = [];
      } else if (raw is List && raw.isNotEmpty && raw.first is List) {
        final List<dynamic> productListFromContract = raw;
        developer.log(
          "DEBUG productListFromContract length: ${productListFromContract.length}",
        );
        products = productListFromContract
            .map((p) {
              // THAY ĐỔI: Product struct giờ chỉ có 6 trường thay vì 7
              if (p is List && p.length == 6) {
                return Product.fromContract(p);
              } else {
                developer.log("WARN unexpected product format: $p");
                return null;
              }
            })
            .whereType<Product>()
            .toList();
      } else {
        developer.log("WARN unexpected raw format: $raw");
        products = [];
      }

      developer.log("DEBUG parsed products length: ${products.length}");

      emit(ProductsLoadedState(products));
    } catch (e) {
      emit(DashboardErrorState("Failed to load products: ${e.toString()}"));
    }
  }
}
