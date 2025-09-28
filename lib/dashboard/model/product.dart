import 'package:web3dart/web3dart.dart';

class Product {
  final String batchId;
  final String name;
  final String organizationName;
  final String creator;
  final BigInt date;
  final String currentOwner;

  Product({
    required this.batchId,
    required this.name,
    required this.organizationName,
    required this.creator,
    required this.date,
    required this.currentOwner,
  });

  factory Product.fromContract(List<dynamic> contractData) {
    if (contractData.length < 6) {
      throw const FormatException("Dữ liệu hợp đồng sản phẩm không hợp lệ");
    }
    return Product(
      batchId: contractData[0] as String,
      name: contractData[1] as String,
      organizationName: contractData[2] as String,
      creator: (contractData[3] as EthereumAddress).hex,
      date: contractData[4] as BigInt,
      currentOwner: (contractData[5] as EthereumAddress).hex,
    );
  }
}
