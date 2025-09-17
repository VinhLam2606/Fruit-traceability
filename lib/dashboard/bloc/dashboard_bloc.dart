// dashboard/bloc/dashboard_bloc.dart
import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:untitled/dashboard/model/product.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web_socket_channel/io.dart';

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

  // Hàm contract cho việc thêm và lấy sản phẩm
  late ContractFunction _addProductFunction;
  // Sửa lại: Dùng một hàm duy nhất để lấy tất cả sản phẩm
  late ContractFunction _getAllProductsFunction;

  FutureOr<void> _dashboardInitialFetchEvent(
    DashboardInitialFetchEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoadingState());
    try {
      const String rpcUrl = "http://10.0.2.2:7545";
      const String socketUrl = "ws://10.0.2.2:7545/";
      const String privateKey =
          "0x9a547e9e81307824733818ef20b1ff42f49920134bb43fe8b98a3fbe3e170967";

      _web3client = Web3Client(
        rpcUrl,
        http.Client(),
        socketConnector: () {
          return IOWebSocketChannel.connect(socketUrl).cast<String>();
        },
      );

      final String abiString = await rootBundle.loadString(
        "build/contracts/Chain.json", // Giả định ABI của bạn chứa contract 'Products'
      );
      final jsonAbi = jsonDecode(abiString);
      // Chú ý: Tên contract trong ABI phải khớp, ví dụ 'Products'
      final abi = ContractAbi.fromJson(jsonEncode(jsonAbi['abi']), 'Products');

      final contractAddress = EthereumAddress.fromHex(
        jsonAbi['networks']['1337']['address'],
      );

      _credentials = EthPrivateKey.fromHex(privateKey);
      _deployedContract = DeployedContract(abi, contractAddress);

      // Khởi tạo các hàm từ contract
      _addProductFunction = _deployedContract.function('addAProduct');
      // Sửa lại tên hàm ở đây
      _getAllProductsFunction = _deployedContract.function('getAllProducts');

      emit(DashboardInitialSuccessState());
    } catch (e) {
      // Thêm thông tin chi tiết vào lỗi để dễ debug
      emit(DashboardErrorState("Initialization failed: ${e.toString()}"));
    }
  }

  FutureOr<void> _createProductButtonPressedEvent(
    CreateProductButtonPressedEvent event,
    Emitter<DashboardState> emit,
  ) async {
    // ... (Phần này không thay đổi)
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
        chainId: 1337,
      );

      emit(
        DashboardSuccessState("Product created successfully! TxHash: $result"),
      );
    } catch (e) {
      emit(DashboardErrorState(e.toString()));
    }
  }

  // Phương thức mới để xử lý việc tải danh sách sản phẩm
  FutureOr<void> _fetchProductsEvent(
    FetchProductsEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoadingState());
    try {
      // 1. Gọi hàm getAllProducts từ contract
      final result = await _web3client.call(
        contract: _deployedContract,
        function: _getAllProductsFunction,
        params: [],
      );

      // web3dart trả về kết quả trong một mảng, nên ta lấy phần tử đầu tiên
      final List<dynamic> productListFromContract = result[0];

      final List<Product> products = [];

      // 2. Lặp qua danh sách trả về và chuyển đổi thành đối tượng Product
      for (final productData in productListFromContract) {
        // Mỗi productData là một mảng các thuộc tính của struct Product
        products.add(Product.fromContract(productData as List<dynamic>));
      }

      emit(ProductsLoadedState(products));
    } catch (e) {
      emit(DashboardErrorState("Failed to load products: ${e.toString()}"));
    }
  }
}
