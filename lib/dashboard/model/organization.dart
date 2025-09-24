import 'package:untitled/dashboard/model/user.dart';
import 'package:web3dart/web3dart.dart';

class Organization {
  final String organizationName;
  final String ownerName;
  final String ownerAddress;
  final List<User> members;
  final BigInt establishedDate;
  final int organizationStatus;

  Organization({
    required this.organizationName,
    required this.ownerName,
    required this.ownerAddress,
    required this.members,
    required this.establishedDate,
    required this.organizationStatus,
  });

  factory Organization.fromContract(List<dynamic> data) {
    // Xử lý trường hợp contract có thể trả về mảng rỗng dưới dạng null.
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
      // Đọc giá trị enum từ contract (dưới dạng BigInt) và chuyển thành int.
      organizationStatus: (data[5] as BigInt).toInt(),
    );
  }
}
