part of 'user_organization_bloc.dart';

abstract class UserOrganizationState {}

class UserOrganizationInitial extends UserOrganizationState {}

class UserOrganizationLoading extends UserOrganizationState {}

class UserOrganizationLoaded extends UserOrganizationState {
  final Organization organization;
  UserOrganizationLoaded(this.organization);
}

class UserOrganizationEmpty extends UserOrganizationState {}

class UserOrganizationLeftSuccess extends UserOrganizationState {
  final String message;
  UserOrganizationLeftSuccess(this.message);
}

class UserOrganizationError extends UserOrganizationState {
  final String message;
  UserOrganizationError(this.message);
}
