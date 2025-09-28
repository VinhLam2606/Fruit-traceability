part of 'organization_bloc.dart';

sealed class OrganizationEvent {}

class FetchOrganizationDetails extends OrganizationEvent {}

class AddMemberToOrganization extends OrganizationEvent {
  final String memberAddress;
  AddMemberToOrganization(this.memberAddress);
}

class RemoveMemberFromOrganization extends OrganizationEvent {
  final String memberAddress;
  RemoveMemberFromOrganization(this.memberAddress);
}
