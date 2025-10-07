part of 'user_organization_bloc.dart';

abstract class UserOrganizationEvent {}

class FetchUserOrganization extends UserOrganizationEvent {}

class LeaveOrganization extends UserOrganizationEvent {}
