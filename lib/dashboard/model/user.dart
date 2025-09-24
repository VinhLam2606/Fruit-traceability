import 'package:web3dart/web3dart.dart';

class User {
  final String userId;
  final String userName;
  // Bạn có thể thêm role nếu cần
  // final int role;

  User({required this.userId, required this.userName});

  factory User.fromContract(List<dynamic> data) {
    return User(
      userId: (data[0] as EthereumAddress).hex,
      userName: data[1] as String,
    );
  }
}
