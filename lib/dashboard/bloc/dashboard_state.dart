// dashboard_state.dart
part of 'dashboard_bloc.dart';

sealed class DashboardState {
  final List<Product> products;

  DashboardState({this.products = const []});
}

final class DashboardInitial extends DashboardState {}

class DashboardLoadingState extends DashboardState {
  DashboardLoadingState({super.products});
}

class DashboardErrorState extends DashboardState {
  final String error;
  DashboardErrorState(this.error, {super.products});
}

class DashboardSuccessState extends DashboardState {
  final String message;
  DashboardSuccessState(this.message, {super.products});
}

class DashboardInitialSuccessState extends DashboardState {}

class ProductsLoadedState extends DashboardState {
  ProductsLoadedState(List<Product> products) : super(products: products);
}
