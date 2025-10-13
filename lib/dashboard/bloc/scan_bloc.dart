// lib/scan/bloc/scan_bloc.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
// Đảm bảo đường dẫn import Product và ProductHistory là chính xác
import 'package:untitled/dashboard/model/product.dart';
import 'package:untitled/dashboard/model/productHistory.dart';
import 'package:web3dart/web3dart.dart';

part 'scan_event.dart';
part 'scan_state.dart';

class ScanBloc extends Bloc<ScanEvent, ScanState> {
  final Web3Client web3client;
  final EthPrivateKey credentials;


  DeployedContract? _deployedContract;
  ContractFunction? _getProductFunction;
  ContractFunction? _getProductHistoryFunction;
  ContractFunction? _updateProductDescriptionFunction;

  ScanBloc({
    required this.web3client,
    required this.credentials
  }) : super(ScanInitialState()) {
    on<ScanInitializeEvent>(_onInitialize);
    on<BarcodeScannedEvent>(_onBarcodeScannedEvent);
    on<FetchProductHistoryEvent>(_onFetchProductHistoryEvent);
    on<UpdateProductDescriptionEvent>(_onUpdateProductDescriptionEvent);

    add(ScanInitializeEvent());
  }

  /// Xử lý Event khởi tạo Bloc và tải Contract ABI/Address.
  FutureOr<void> _onInitialize(
      ScanInitializeEvent event, Emitter<ScanState> emit) async {
    try {
      final abiString = await rootBundle.loadString("build/contracts/Chain.json");
      final jsonAbi = jsonDecode(abiString);
      final abi = ContractAbi.fromJson(jsonEncode(jsonAbi['abi']), 'Chain');

      final networks = jsonAbi['networks'] as Map<String, dynamic>;
      final networkKey = networks.keys.first;
      final contractAddressHex = networks[networkKey]['address'] as String?;

      if (contractAddressHex == null || contractAddressHex.isEmpty) {
        throw Exception("❌ Không tìm thấy contract address trong Chain.json.");
      }

      final contractAddress = EthereumAddress.fromHex(contractAddressHex);
      _deployedContract = DeployedContract(abi, contractAddress);

      _getProductFunction = _deployedContract!.function('getProduct');
      _getProductHistoryFunction = _deployedContract!.function('getProductHistory');
      _updateProductDescriptionFunction = _deployedContract!.function('updateProductDescription');

      developer.log("📌 ScanBloc Contract address loaded: $contractAddress");

    } catch (e, st) {
      developer.log("❌ [Init] ScanBloc error: $e", stackTrace: st);
      emit(ScanErrorState("Lỗi khởi tạo contract: ${e.toString()}"));
    }
  }

  FutureOr<void> _onBarcodeScannedEvent(
      BarcodeScannedEvent event,
      Emitter<ScanState> emit,
      ) async {
    if (_deployedContract == null || _getProductFunction == null) {
      emit(ScanErrorState("Lỗi: Contract chưa được tải. Vui lòng thử lại sau giây lát.\nVui lòng scan lại."));
      return;
    }

    emit(ScanLoadingState());
    final batchId = event.batchId;

    try {
      final deployedContract = _deployedContract!;
      final getProductFunction = _getProductFunction!;

      // 1. Gọi getProduct(batchId)
      final result = await web3client.call(
        contract: deployedContract,
        function: getProductFunction,
        params: [batchId],
      );

      if (result.isEmpty || result.first is! List) {
        throw Exception("❌ Không lấy được dữ liệu sản phẩm từ blockchain.");
      }

      final rawProductData = result.first as List<dynamic>;
      final product = Product.fromContract(rawProductData);

      developer.log("✅ Loaded Product: ${product.name} (Batch: $batchId)");

      emit(ProductInfoLoadedState(product: product));

    } catch (e, st) {
      developer.log("❌ [GetProduct] Failed", error: e, stackTrace: st);
      emit(ScanErrorState("❌ Lỗi lấy thông tin sản phẩm: ${e.toString()}"));
    }
  }

  /// Xử lý sự kiện nhấn nút chi tiết: Gọi getProductHistory.
  FutureOr<void> _onFetchProductHistoryEvent(
      FetchProductHistoryEvent event,
      Emitter<ScanState> emit,
      ) async {
    if (_deployedContract == null || _getProductHistoryFunction == null) {
      emit(ScanErrorState("Lỗi: Contract chưa được tải. Vui lòng thử lại sau giây lát.\nVui lòng scan lại."));
      return;
    }

    // Chỉ tải lịch sử khi đã có thông tin sản phẩm
    if (state is! ProductInfoLoadedState) return;

    final currentState = state as ProductInfoLoadedState;
    final deployedContract = _deployedContract!;
    final getProductHistoryFunction = _getProductHistoryFunction!;

    emit(ProductHistoryLoadingState(
      product: currentState.product,
      history: currentState.history,
      historyErrorMessage: null,
    ));

    try {
      // ✅ SỬA ĐỔI TẠI ĐÂY: Thêm `from: credentials.address`
      // This ensures `msg.sender` is set for the contract call, allowing it
      // to check if the user is registered.
      final result = await web3client.call(
        contract: deployedContract,
        function: getProductHistoryFunction,
        params: [event.batchId],
        sender: credentials.address,
      );

      final rawHistory = result.first as List;
      final history = rawHistory
          .map((h) => (h is List) ? ProductHistory.fromContract(h) : null)
          .whereType<ProductHistory>()
          .toList();

      developer.log("✅ Loaded ${history.length} product history items.");

      emit(ProductDetailsLoadedState(
        product: currentState.product,
        history: history,
        historyErrorMessage: null,
      ));

    } catch (e, st) {
      developer.log("❌ [GetProductHistory] Failed", error: e, stackTrace: st);

      emit(currentState.copyWith(
        historyErrorMessage: "❌ Lỗi tải lịch sử sản phẩm: ${e.toString()}",
      ));
    }
  }

  FutureOr<void> _onUpdateProductDescriptionEvent(
      UpdateProductDescriptionEvent event, Emitter<ScanState> emit) async {
    if (state is! ProductInfoLoadedState) return;
    final currentState = state as ProductInfoLoadedState;

    emit(ProductHistoryLoadingState(
        product: currentState.product, history: currentState.history));

    try {
      final txHash = await web3client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: _deployedContract!,
          function: _updateProductDescriptionFunction!,
          parameters: [event.batchId, event.description],
        ),
        chainId: 1337,
      );
      developer.log("✅ Product info updated! TxHash: $txHash");
      // Sau khi cập nhật thành công, tự động tải lại lịch sử để thấy thay đổi
      add(FetchProductHistoryEvent(event.batchId));
    } catch (e, st) {
      developer.log("❌ [UpdateProduct] Failed", error: e, stackTrace: st);
      emit(currentState.copyWith(
          historyErrorMessage: "❌ Lỗi cập nhật: ${e.toString()}"));
    }
  }
}