// lib/scan/bloc/scan_state.dart

part of 'scan_bloc.dart';

sealed class ScanState {}

final class ScanInitialState extends ScanState {}

final class ScanLoadingState extends ScanState {}

final class ScanErrorState extends ScanState {
  final String error;
  ScanErrorState(this.error);
}

class ProductInfoLoadedState extends ScanState {
  final Product product;
  final List<ProductHistory>? history;
  final String? historyErrorMessage;

  ProductInfoLoadedState({
    required this.product,
    this.history,
    this.historyErrorMessage,
  });

  ProductInfoLoadedState copyWith({
    List<ProductHistory>? history,
    String? historyErrorMessage,
  }) {
    return ProductInfoLoadedState(
      product: product,
      history: history ?? this.history,
      historyErrorMessage: historyErrorMessage,
    );
  }
}

final class ProductHistoryLoadingState extends ProductInfoLoadedState {
  ProductHistoryLoadingState({
    required super.product,
    super.history,
    super.historyErrorMessage,
  });
}

// === THAY ĐỔI: State này giờ chứa danh sách timeline đã gộp ===
class ProductDetailsLoadedState extends ProductInfoLoadedState {
  // `history` trong state cha (ProductInfoLoadedState) sẽ là null
  final List<TimelineItem> timeline; // <-- Dùng model timeline mới

  ProductDetailsLoadedState({
    required super.product,
    required this.timeline, // <-- Danh sách đã gộp
    super.historyErrorMessage,
  }) : super(
    history: null, // Không dùng `history` gốc nữa
  );
}