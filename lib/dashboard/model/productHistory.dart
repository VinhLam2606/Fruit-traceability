// productHistory.dart

// ignore_for_file: file_names

import 'package:web3dart/web3dart.dart';

enum HistoryType {
  create,
  transferred,
  processed
}

class ProductHistory {
  final String batchId;
  final String from;
  final String to;
  final String note;
  final BigInt timestamp;
  final HistoryType type;


  ProductHistory({
    required this.batchId,
    required this.from,
    required this.to,
    required this.note,
    required this.timestamp,
    required this.type,
  });

  /// Parse từ struct ProductHistory trong Solidity
  factory ProductHistory.fromContract(List<dynamic> contractData) {
    if (contractData.length != 6) {
      throw const FormatException(
          "Dữ liệu hợp đồng lịch sử sản phẩm không hợp lệ");
    }

    int typeIndex = (contractData[5] as BigInt).toInt();

    return ProductHistory(
      batchId: contractData[0] as String,
      from: (contractData[1] as EthereumAddress).hex,
      to: (contractData[2] as EthereumAddress).hex,
      timestamp: contractData[3] as BigInt,
      note: contractData[4] as String,
      type: HistoryType.values[typeIndex],
    );
  }

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(timestamp.toInt() * 1000, isUtc: true).toLocal();

  Map<String, dynamic> toJson() => {
    'batchId': batchId,
    'from': from,
    'to': to,
    'timestamp': timestamp.toString(),
    'note': note,
    'type': type.toString(),
    'dateTime': dateTime.toIso8601String(),
  };

  @override
  String toString() =>
      'ProductHistory(batchId: $batchId, from: $from, to: $to, type: $type, note: $note, time: $dateTime)';
}