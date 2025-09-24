part of 'dashboard_bloc.dart';

sealed class DashboardEvent {}

// Event để khởi tạo kết nối với blockchain
class DashboardInitialFetchEvent extends DashboardEvent {}

// Event để tải danh sách sản phẩm
class FetchProductsEvent extends DashboardEvent {}

// Event được kích hoạt khi người dùng nhấn nút tạo sản phẩm
// THAY ĐỔI: Cập nhật event để sử dụng một trường 'date'
class CreateProductButtonPressedEvent extends DashboardEvent {
  final String batchId;
  final String name;
  final int date; // Gộp hai trường date cũ thành một

  CreateProductButtonPressedEvent({
    required this.batchId,
    required this.name,
    required this.date, // Cập nhật constructor
  });
}

// Event mới: đăng ký tổ chức và tạo sản phẩm (giữ nguyên nếu logic không đổi)
class RegisterOrgAndCreateProductEvent extends DashboardEvent {
  final String orgName;
  final String batchId;
  final String name;
  final int date; // Cũng cần cập nhật ở đây nếu sử dụng
  // Giả sử chỉ cần cập nhật ở event trên, nhưng để nhất quán thì nên sửa cả ở đây

  RegisterOrgAndCreateProductEvent({
    required this.orgName,
    required this.batchId,
    required this.name,
    required this.date,
  });
}
