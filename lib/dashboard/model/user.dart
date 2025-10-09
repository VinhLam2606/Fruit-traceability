// lib/dashboard/model/user.dart

import 'package:web3dart/web3dart.dart';

class User {
  final String userId;
  final String userName;
  final String role; // ✅ Đã thêm trường role (String)

  User({
    required this.userId,
    required this.userName,
    required this.role, // ✅ Cần tham số role trong constructor
  });

  // Hàm này ánh xạ roleIndex (BigInt) từ contract thành chuỗi (String)
  static String _mapRole(int roleIndex) {
    switch (roleIndex) {
      case 0:
        return "Admin";
      case 1:
        return "Organization";
      case 2:
        return "Customer";
      default:
        return "Unknown";
    }
  }

  factory User.fromContract(List<dynamic> data) {
    // Giả định cấu trúc mảng từ contract là: [address, name, roleIndex, isInOrg, ...]

    // Xử lý roleIndex (thường là BigInt ở vị trí 2)
    final roleIndex = (data.length > 2) ? (data[2] as BigInt).toInt() : -1;

    return User(
      userId: (data[0] as EthereumAddress).hex,
      userName: data[1] as String,
      role: _mapRole(roleIndex), // ✅ Ánh xạ role
    );
  }
}
