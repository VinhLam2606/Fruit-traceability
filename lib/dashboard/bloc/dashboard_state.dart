part of 'dashboard_bloc.dart';

sealed class DashboardState {}

final class DashboardInitial extends DashboardState {}

class DashboardLoadingState extends DashboardState {}

class DashboardErrorState extends DashboardState {
  final String error;
  DashboardErrorState(this.error);
}

class DashboardSuccessState extends DashboardState {
  final String message;
  DashboardSuccessState(this.message);
}

// ----------------- PRODUCT STATES -----------------
class DashboardInitialSuccessState extends DashboardState {}

class ProductsLoadedState extends DashboardState {
  final List<Product> products;
  ProductsLoadedState(this.products);
}

