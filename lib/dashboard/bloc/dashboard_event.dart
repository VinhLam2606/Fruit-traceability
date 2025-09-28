part of 'dashboard_bloc.dart';

sealed class DashboardEvent {}

// ----------------- PRODUCT EVENTS -----------------
class DashboardInitialFetchEvent extends DashboardEvent {}

class FetchProductsEvent extends DashboardEvent {}

class CreateProductButtonPressedEvent extends DashboardEvent {
  final String batchId;
  final String name;
  final int harvestDate;
  final int expiryDate;
  CreateProductButtonPressedEvent({
    required this.batchId,
    required this.name,
    required this.harvestDate,
    required this.expiryDate,
  });
}

// Event mới: đăng ký tổ chức và tạo sản phẩm
class RegisterOrgAndCreateProductEvent extends DashboardEvent {
  final String orgName;
  final String batchId;
  final String name;
  final int harvestDate;
  final int expiryDate;

  RegisterOrgAndCreateProductEvent({
    required this.orgName,
    required this.batchId,
    required this.name,
    required this.harvestDate,
    required this.expiryDate,
  });
}
