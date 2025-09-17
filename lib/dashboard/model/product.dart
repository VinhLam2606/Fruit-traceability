import 'package:web3dart/web3dart.dart';

// dashboard/model/product.dart
class Product {
  final String batchId;
  final String name;
  final String organizationName; // Thêm
  final EthereumAddress creator; // Thêm
  final BigInt harvestDate;
  final BigInt expiryDate;
  final EthereumAddress currentOwner; // Thêm

  Product({
    required this.batchId,
    required this.name,
    required this.organizationName, // Thêm
    required this.creator, // Thêm
    required this.harvestDate,
    required this.expiryDate,
    required this.currentOwner, // Thêm
  });

  // Cập nhật factory constructor để khớp với thứ tự các trường trong struct Solidity
  // Types.Product: (string, string, string, address, uint256, uint256, address)
  factory Product.fromContract(List<dynamic> data) {
    return Product(
      batchId: data[0] as String,
      name: data[1] as String,
      organizationName: data[2] as String,
      creator: data[3] as EthereumAddress,
      harvestDate: data[4] as BigInt,
      expiryDate: data[5] as BigInt,
      currentOwner: data[6] as EthereumAddress,
    );
  }
}
