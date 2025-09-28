// dashboard/bloc/organization_state.dart
part of 'organization_bloc.dart';

abstract class OrganizationState {}

class OrganizationInitial extends OrganizationState {}

class OrganizationLoading extends OrganizationState {}

class OrganizationLoaded extends OrganizationState {
  final Organization organization;
  // THAY ĐỔI: Xóa bỏ danh sách sản phẩm
  // final List<Product> products;

  OrganizationLoaded(this.organization);
}

class OrganizationActionSuccess extends OrganizationState {
  final String message;
  OrganizationActionSuccess(this.message);
}

class OrganizationError extends OrganizationState {
  final String error;
  OrganizationError(this.error);
}
