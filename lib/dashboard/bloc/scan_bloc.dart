// lib/scan/bloc/scan_bloc.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:untitled/dashboard/model/product.dart';
import 'package:untitled/dashboard/model/productHistory.dart';
// === THÊM MỚI: Import model timeline ===
import 'package:untitled/dashboard/model/timeline_item.dart';
import 'package:web3dart/web3dart.dart';

part 'scan_event.dart';
part 'scan_state.dart';

class ScanBloc extends Bloc<ScanEvent, ScanState> {
  final Web3Client web3client;
  final EthPrivateKey credentials;

  DeployedContract? _deployedContract;
  ContractFunction? _getProductFunction;
  ContractFunction? _getProductHistoryFunction;
  ContractFunction? _addProcessStepFunction;

  ScanBloc({
    required this.web3client,
    required this.credentials
  }) : super(ScanInitialState()) {
    on<ScanInitializeEvent>(_onInitialize);
    on<BarcodeScannedEvent>(_onBarcodeScannedEvent);
    on<FetchProductHistoryEvent>(_onFetchProductHistoryEvent); // <-- Đã viết lại
    on<AddProcessStepEvent>(_onAddProcessStepEvent); // <-- Đã viết lại

    add(ScanInitializeEvent());
  }

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
      _addProcessStepFunction = _deployedContract!.function('addProcessStep');
      developer.log("📌 ScanBloc Contract address loaded: $contractAddress");
    } catch (e, st) {
      developer.log("❌ [Init] ScanBloc error: $e", stackTrace: st);
      emit(ScanErrorState("Không thể tải thông tin hệ thống. Vui lòng kiểm tra kết nối và thử lại."));
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
      emit(ScanErrorState("❌ Không thể lấy thông tin sản phẩm. Vui lòng quét lại mã."));
    }
  }

  // === THAY ĐỔI LỚN: VIẾT LẠI HOÀN TOÀN HÀM NÀY ===
  FutureOr<void> _onFetchProductHistoryEvent(
      FetchProductHistoryEvent event,
      Emitter<ScanState> emit,
      ) async {
    // Kiểm tra tất cả các hàm cần thiết
    if (_deployedContract == null ||
        _getProductHistoryFunction == null ||
        _getProductFunction == null) {
      emit(ScanErrorState(
          "Lỗi: Contract chưa được tải. Vui lòng thử lại sau giây lát.\nVui lòng scan lại."));
      return;
    }

    if (state is! ProductInfoLoadedState) return;

    final currentState = state as ProductInfoLoadedState;
    final deployedContract = _deployedContract!;
    final getProductHistoryFunction = _getProductHistoryFunction!;
    final getProductFunction = _getProductFunction!; // Cần hàm này để lấy processSteps

    emit(ProductHistoryLoadingState(
      product: currentState.product,
      history: currentState.history,
      historyErrorMessage: null,
    ));

    try {
      // === BƯỚC 1: Tải cả hai danh sách CÙNG LÚC ===

      // Tải Lịch sử (ProductHistory[])
      final historyResultFuture = web3client.call(
        contract: deployedContract,
        function: getProductHistoryFunction,
        params: [event.batchId],
        sender: credentials.address,
      );

      // Tải Sản phẩm (để lấy ProcessStep[] chi tiết)
      final productResultFuture = web3client.call(
        contract: deployedContract,
        function: getProductFunction,
        params: [event.batchId],
      );

      // Chờ cả hai hoàn tất
      final results = await Future.wait([historyResultFuture, productResultFuture]);

      // === BƯỚC 2: Parse kết quả ===

      // Parse History
      final rawHistory = (results[0] as List).first as List;
      final historyEvents = rawHistory
          .map((h) => (h is List) ? ProductHistory.fromContract(h) : null)
          .whereType<ProductHistory>()
          .toList();

      // Parse Product và lấy ProcessSteps
      final rawProductData = (results[1] as List).first as List<dynamic>;
      final Product freshProduct = Product.fromContract(rawProductData);
      final List<ProcessStep> processSteps = freshProduct.processSteps;

      developer.log("✅ Loaded ${historyEvents.length} history items.");
      developer.log("✅ Loaded ${processSteps.length} process steps.");

      // === BƯỚC 3: Gộp (Merge) hai danh sách ===

      // Tạo Map để tra cứu ProcessStep bằng timestamp (BigInt)
      // `date` trong ProcessStep được gán bằng `block.timestamp`
      final Map<BigInt, ProcessStep> processDetailsMap = {
        for (var step in processSteps) step.date: step
      };

      List<TimelineItem> timelineItems = [];

      for (var historyEvent in historyEvents) {
        // `timestamp` trong ProductHistory cũng được gán bằng `block.timestamp`
        final BigInt timestamp = historyEvent.timestamp;

        // Nếu là Processed...
        if (historyEvent.type == HistoryType.processed) {
          // ...thử tìm thông tin chi tiết của nó trong Map
          final ProcessStep? matchingDetail = processDetailsMap[timestamp];

          if (matchingDetail != null) {
            // 🟠 Tìm thấy! Thêm ProcessEventItem (viền cam)
            timelineItems.add(ProcessEventItem(matchingDetail));
            // Xóa khỏi map để tránh trùng lặp (nếu cần)
            processDetailsMap.remove(timestamp);
          } else {
            // Không tìm thấy chi tiết (lỗi hiếm gặp)
            developer.log("⚠️ Không tìm thấy ProcessStep chi tiết cho timestamp $timestamp");
            // Vẫn thêm sự kiện gốc (viền xanh)
            timelineItems.add(HistoryEventItem(historyEvent));
          }
        }
        // Nếu là Create hoặc Transfer...
        else {
          // 🔵 Thêm HistoryEventItem (viền xanh)
          timelineItems.add(HistoryEventItem(historyEvent));
        }
      }

      // Sắp xếp lại danh sách cuối cùng theo timestamp (tăng dần)
      timelineItems.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // === BƯỚC 4: Emit state cuối cùng ===
      emit(ProductDetailsLoadedState(
        product: freshProduct, // Dùng product mới nhất
        timeline: timelineItems, // Dùng timeline đã gộp
      ));

    } catch (e, st) {
      developer.log("❌ [GetProductHistory/Merge] Failed", error: e, stackTrace: st);
      emit(currentState.copyWith(
        historyErrorMessage: "❌ Không thể tải lịch sử sản phẩm. Vui lòng thử lại sau.",
      ));
    }
  }

  // === THAY ĐỔI: Tối ưu logic refresh ===
  FutureOr<void> _onAddProcessStepEvent(
      AddProcessStepEvent event, Emitter<ScanState> emit) async {
    if (state is! ProductInfoLoadedState) return;
    final currentState = state as ProductInfoLoadedState;

    // Hiển thị loading, nhưng giữ nguyên nội dung cũ
    emit(ProductHistoryLoadingState(
        product: currentState.product,
        history: currentState.history
    ));

    try {
      final txHash = await web3client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: _deployedContract!,
          function: _addProcessStepFunction!,
          parameters: [
            event.batchId,
            event.processName,
            BigInt.from(event.processType),
            event.description,
          ],
        ),
        chainId: 1337, // Đảm bảo chainId của bạn (ví dụ: 1337 cho Ganache)
      );
      developer.log("✅ Process step added! TxHash: $txHash");

      // === LOGIC REFRESH THÔNG MINH ===
      // 1. Tải lại sản phẩm (để cập nhật `status` và `processSteps`)
      add(BarcodeScannedEvent(event.batchId));

      // 2. Chờ BLoC xử lý xong BarcodeScannedEvent (trở về state ProductInfoLoadedState)
      //    rồi MỚI tải timeline (đã bao gồm process mới)
      stream.firstWhere((state) => state is ProductInfoLoadedState && state.product.batchId == event.batchId)
          .then((_) {
        if (!isClosed) {
          // 3. Giờ thì tải timeline đã gộp
          add(FetchProductHistoryEvent(event.batchId));
        }
      });

    } catch (e, st) {
      developer.log("❌ [AddProcessStep] Failed", error: e, stackTrace: st);
      emit(currentState.copyWith(
          historyErrorMessage: "❌ Không thể thêm quy trình. Vui lòng kiểm tra quyền truy cập."));
    }
  }
}