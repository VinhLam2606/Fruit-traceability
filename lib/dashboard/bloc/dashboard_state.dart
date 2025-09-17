// dashboard/bloc/dashboard_state.dart
part of 'dashboard_bloc.dart';

sealed class DashboardState {}

final class DashboardInitial extends DashboardState {}

class DashboardLoadingState extends DashboardState {}

class DashboardErrorState extends DashboardState {
  final String error;
  DashboardErrorState(this.error);
}

// Trạng thái chung cho thành công, có thể dùng cho nhiều việc
class DashboardSuccessState extends DashboardState {
  final String message;
  DashboardSuccessState(this.message);
}

// Trạng thái cụ thể sau khi khởi tạo thành công
class DashboardInitialSuccessState extends DashboardState {}

// Trạng thái mới: Tải danh sách sản phẩm thành công
class ProductsLoadedState extends DashboardState {
  final List<Product> products;
  ProductsLoadedState(this.products);
}
