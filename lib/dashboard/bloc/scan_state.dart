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
    this.historyErrorMessage, // Thêm vào constructor
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
    required Product product,
    List<ProductHistory>? history,
    String? historyErrorMessage,
  }) : super(product: product, history: history, historyErrorMessage: historyErrorMessage);
}

class ProductDetailsLoadedState extends ProductInfoLoadedState {
  @override
  final List<ProductHistory> history;

  ProductDetailsLoadedState({
    required Product product,
    required this.history,
    String? historyErrorMessage,
  }) : super(product: product, history: history, historyErrorMessage: historyErrorMessage);
}