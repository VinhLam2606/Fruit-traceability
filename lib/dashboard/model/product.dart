import 'package:web3dart/web3dart.dart';

class ProcessStep {
  final String processName;
  final int processType;
  final String description;
  final BigInt date;
  final String organizationName;

  ProcessStep({
    required this.processName,
    required this.processType,
    required this.description,
    required this.date,
    required this.organizationName,
  });

  factory ProcessStep.fromContract(List<dynamic> data) {
    if (data.length != 5) {
      throw FormatException("Dữ liệu ProcessStep không hợp lệ: $data");
    }

    return ProcessStep(
      processName: data[0] as String,
      processType: (data[1] as BigInt).toInt(),
      description: data[2] as String,
      date: data[3] as BigInt,
      organizationName: data[4] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'processName': processName,
    'processType': processType,
    'description': description,
    'date': date.toString(),
    'organizationName': organizationName,
  };
}

class Product {
  final String batchId;
  final String name;
  final String organizationName;
  final String creator;
  final BigInt date;
  final String currentOwner;
  final String status;
  final String seedVariety;
  final String origin;
  final List<ProcessStep> processSteps;

  Product({
    required this.batchId,
    required this.name,
    required this.organizationName,
    required this.creator,
    required this.date,
    required this.currentOwner,
    required this.status,
    required this.seedVariety, // Sửa thứ tự
    required this.origin, // Sửa thứ tự
    required this.processSteps,
  });

  factory Product.fromContract(List<dynamic> contractData) {
    // Sửa lỗi #1: Kiểm tra 9 trường là đúng
    if (contractData.length != 10) {
      throw FormatException(
        "Dữ liệu hợp đồng sản phẩm không hợp lệ (mong đợi 10, nhận ${contractData.length}): $contractData",
      );
    }

    final rawSteps = contractData[9] as List<dynamic>;
    final steps = rawSteps
        .map((step) => ProcessStep.fromContract(step as List<dynamic>))
        .toList();

    return Product(
      batchId: contractData[0] as String,
      name: contractData[1] as String,
      organizationName: contractData[2] as String,
      creator: (contractData[3] as EthereumAddress).hex,
      date: contractData[4] as BigInt,
      currentOwner: (contractData[5] as EthereumAddress).hex,
      status: contractData[6] as String,
      seedVariety: contractData[7] as String, // Index 7
      origin: contractData[8] as String, // Index 8
      processSteps: steps,
    );
  }

  Map<String, dynamic> toJson() => {
    'batchId': batchId,
    'name': name,
    'organizationName': organizationName,
    'creator': creator,
    'date': date.toString(),
    'currentOwner': currentOwner,
    'status': status,
    'seedVariety': seedVariety,
    'origin': origin,
    'processSteps': processSteps.map((step) => step.toJson()).toList(),
  };

  @override
  String toString() =>
      'Product(batchId: $batchId, name: $name, org: $organizationName, '
      'creator: $creator, date: $date, owner: $currentOwner, status: $status, seed: $seedVariety, origin: $origin,'
      'processSteps: ${processSteps.length})';
}
