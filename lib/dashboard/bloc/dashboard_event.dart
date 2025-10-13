part of 'dashboard_bloc.dart';

sealed class DashboardEvent {}

// Event để khởi tạo kết nối với blockchain
class DashboardInitialFetchEvent extends DashboardEvent {}

// Event để tải danh sách sản phẩm
class FetchProductsEvent extends DashboardEvent {}

// Event được kích hoạt khi người dùng nhấn nút tạo sản phẩm
class CreateProductButtonPressedEvent extends DashboardEvent {
  final String batchId;
  final String name;
  final int date;

  CreateProductButtonPressedEvent({
    required this.batchId,
    required this.name,
    required this.date,
  });
}

class TransferProductEvent extends DashboardEvent {
  final String batchId;
  final String receiverOrganizationId; // Tên/ID tổ chức nhận

  TransferProductEvent({
    required this.batchId,
    required this.receiverOrganizationId,
  });
}

class RegisterOrgAndCreateProductEvent extends DashboardEvent {
  final String orgName;
  final String batchId;
  final String name;
  final int date;

  RegisterOrgAndCreateProductEvent({
    required this.orgName,
    required this.batchId,
    required this.name,
    required this.date,
  });
}
