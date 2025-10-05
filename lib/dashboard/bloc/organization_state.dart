part of 'organization_bloc.dart';

/// Các state cho OrganizationBloc
abstract class OrganizationState {}

/// State mặc định ban đầu
class OrganizationInitial extends OrganizationState {}

/// State loading khi đang gọi blockchain
class OrganizationLoading extends OrganizationState {}

/// State thành công khi lấy được chi tiết tổ chức
class OrganizationLoaded extends OrganizationState {
  final Organization organization;
  OrganizationLoaded(this.organization);
}

/// State khi một hành động thành công (thêm/xoá thành viên...)
class OrganizationActionSuccess extends OrganizationState {
  final String message;
  OrganizationActionSuccess(this.message);
}

/// State khi có lỗi (user không phải org hoặc blockchain lỗi)
class OrganizationError extends OrganizationState {
  final String error;
  OrganizationError(this.error);
}

/// State riêng: user hiện tại không phải Organization
class NotOrganizationState extends OrganizationState {}
