// ignore_for_file: file_names

import 'package:web3dart/web3dart.dart';

class ProductHistory {
  final String batchId;
  final String from;
  final String to;
  final String note;
  final BigInt timestamp;

  ProductHistory({
    required this.batchId,
    required this.from,
    required this.to,
    required this.note,
    required this.timestamp,
  });

  /// Parse từ struct ProductHistory trong Solidity
  factory ProductHistory.fromContract(List<dynamic> contractData) {
    if (contractData.length < 5) {
      throw const FormatException(
          "Dữ liệu hợp đồng lịch sử sản phẩm không hợp lệ");
    }

    return ProductHistory(
      batchId: contractData[0] as String,
      from: (contractData[1] as EthereumAddress).hex,
      to: (contractData[2] as EthereumAddress).hex,
      note: contractData[3] as String,
      timestamp: contractData[4] as BigInt,
    );
  }

  /// Chuyển BigInt timestamp sang DateTime
  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(timestamp.toInt() * 1000);
}
