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

class AddProcessStepEvent extends ScanEvent {
  final String batchId;
  final String processName;
  final int processType;
  final String description;

  AddProcessStepEvent({
    required this.batchId,
    required this.processName,
    required this.processType,
    required this.description,
  });
}