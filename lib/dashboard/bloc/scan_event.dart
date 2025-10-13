// lib/scan/bloc/scan_event.dart

part of 'scan_bloc.dart';

sealed class ScanEvent {}

class ScanInitializeEvent extends ScanEvent {}

class BarcodeScannedEvent extends ScanEvent {
  final String batchId;
  BarcodeScannedEvent(this.batchId);
}

class FetchProductHistoryEvent extends ScanEvent {
  final String batchId;
  FetchProductHistoryEvent(this.batchId);
}

class UpdateProductDescriptionEvent extends ScanEvent {
  final String batchId;
  final String description;

  UpdateProductDescriptionEvent({
    required this.batchId,
    required this.description,
  });
}