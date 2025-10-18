// lib/dashboard/model/organization.dart

import 'package:untitled/dashboard/model/user.dart';
import 'package:web3dart/web3dart.dart';

class Organization {
  // Dữ liệu từ Smart Contract
  final String organizationName;
  final String ownerName;
  final String ownerAddress;
  final List<User> members;
  final BigInt establishedDate;
  final int organizationStatus;

  // Dữ liệu từ Firebase
  final String? brandName;
  final String? businessType;
  final String? foundedYear;
  final String? address;
  final String? email;
  final String? phoneNumber;

  Organization({
    // Dữ liệu từ Smart Contract
    required this.organizationName,
    required this.ownerName,
    required this.ownerAddress,
    required this.members,
    required this.establishedDate,
    required this.organizationStatus,

    // Dữ liệu từ Firebase (có thể null)
    this.brandName,
    this.businessType,
    this.foundedYear,
    this.address,
    this.email,
    this.phoneNumber,
  });

  factory Organization.fromContract(List<dynamic> data) {
    final List<dynamic> memberData = data.length > 3 && data[3] != null
        ? data[3] as List<dynamic>
        : [];

    final members = memberData
        .map((m) => User.fromContract(m as List<dynamic>))
        .toList();

    return Organization(
      organizationName: data[0] as String,
      ownerName: data[1] as String,
      ownerAddress: (data[2] as EthereumAddress).hex,
      members: members,
      establishedDate: data[4] as BigInt,
      organizationStatus: (data[5] as BigInt).toInt(),
    );
  }

  Organization copyWith({
    String? organizationName,
    String? ownerName,
    String? ownerAddress,
    List<User>? members,
    BigInt? establishedDate,
    int? organizationStatus,
    // Thêm các trường từ Firebase
    String? brandName,
    String? businessType,
    String? foundedYear,
    String? address,
    String? email,
    String? phoneNumber,
  }) {
    return Organization(
      organizationName: organizationName ?? this.organizationName,
      ownerName: ownerName ?? this.ownerName,
      ownerAddress: ownerAddress ?? this.ownerAddress,
      members: members ?? this.members,
      establishedDate: establishedDate ?? this.establishedDate,
      organizationStatus: organizationStatus ?? this.organizationStatus,
      // Gán giá trị mới hoặc giữ lại giá trị cũ
      brandName: brandName ?? this.brandName,
      businessType: businessType ?? this.businessType,
      foundedYear: foundedYear ?? this.foundedYear,
      address: address ?? this.address,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}
