part of 'organization_bloc.dart';

// KHÔNG CÓ IMPORT Ở ĐÂY

sealed class OrganizationState {}

class OrganizationInitial extends OrganizationState {}

class OrganizationLoading extends OrganizationState {}

class OrganizationLoaded extends OrganizationState {
  final Organization organization;
  final List<Product> products;
  OrganizationLoaded(this.organization, this.products);
}

class OrganizationActionSuccess extends OrganizationState {
  final String message;
  OrganizationActionSuccess(this.message);
}

class OrganizationError extends OrganizationState {
  final String error;
  OrganizationError(this.error);
}
