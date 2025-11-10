// lib/dashboard/bloc/dashboard_event.dart
part of 'dashboard_bloc.dart';

sealed class DashboardEvent {}

class DashboardInitialFetchEvent extends DashboardEvent {}

class FetchProductsEvent extends DashboardEvent {}

class CreateProductButtonPressedEvent extends DashboardEvent {
  final String batchId;
  final String name;
  final int date;
  final String seedVariety;
  final String origin;
  final Completer<bool>? completer; // ✅ THÊM DÒNG NÀY

  CreateProductButtonPressedEvent({
    required this.batchId,
    required this.name,
    required this.date,
    required this.seedVariety,
    required this.origin,
    this.completer, // ✅ THÊM DÒNG NÀY
  });
}

class TransferProductEvent extends DashboardEvent {
  final String batchId;
  final String receiverOrganizationId;
  final Completer<bool>? completer; // ✅ THÊM DÒNG NÀY

  TransferProductEvent({
    required this.batchId,
    required this.receiverOrganizationId,
    this.completer, // ✅ THÊM DÒNG NÀY
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
