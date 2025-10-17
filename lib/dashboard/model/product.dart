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
  final List<ProcessStep> processSteps;

  Product({
    required this.batchId,
    required this.name,
    required this.organizationName,
    required this.creator,
    required this.date,
    required this.currentOwner,
    required this.status,
    required this.processSteps,
  });

  factory Product.fromContract(List<dynamic> contractData) {
    if (contractData.length != 8) {
      throw FormatException("Dữ liệu hợp đồng sản phẩm không hợp lệ: $contractData");
    }

    // Parse danh sách các bước quy trình (ProcessStep[])
    final rawSteps = contractData[7] as List<dynamic>;
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
    'processSteps': processSteps.map((step) => step.toJson()).toList(),
  };

  @override
  String toString() =>
      'Product(batchId: $batchId, name: $name, org: $organizationName, '
          'creator: $creator, date: $date, owner: $currentOwner, status: $status,'
          'processSteps: ${processSteps.length})';
}
