part of 'organization_bloc.dart';

/// Các sự kiện cho OrganizationBloc
sealed class OrganizationEvent {}

/// Lấy chi tiết tổ chức (chỉ dành cho Organization)
class FetchOrganizationDetails extends OrganizationEvent {}

/// Thêm thành viên mới vào tổ chức (chỉ Organization mới có quyền)
class AddMemberToOrganization extends OrganizationEvent {
  final String memberAddress;
  AddMemberToOrganization(this.memberAddress);
}

/// Xoá thành viên khỏi tổ chức (chỉ Organization mới có quyền)
class RemoveMemberFromOrganization extends OrganizationEvent {
  final String memberAddress;
  RemoveMemberFromOrganization(this.memberAddress);
}
