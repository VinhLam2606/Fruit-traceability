import 'dart:async';
import 'dart:developer' as developer;

import 'package:bloc/bloc.dart';
import 'package:untitled/auth/service/auth_service.dart';
import 'package:web3dart/web3dart.dart';

part 'account_event.dart';
part 'account_state.dart';

class AccountBloc extends Bloc<AccountEvent, AccountState> {
  final Web3Client _web3client;
  final DeployedContract _deployedContract;
  late ContractFunction _getUserFunction;

  AccountBloc({
    required Web3Client web3client,
    required DeployedContract deployedContract,
  }) : _web3client = web3client,
       _deployedContract = deployedContract,
       super(AccountInitial()) {
    _getUserFunction = _deployedContract.function('getUser');
    on<FetchAccountDetails>(_onFetchAccountDetails);
  }

  Future<void> _onFetchAccountDetails(
    FetchAccountDetails event,
    Emitter<AccountState> emit,
  ) async {
    emit(AccountLoading());
    try {
      // 🔑 Lấy private key từ AuthService
      final privateKey = authService.value.decryptedPrivateKey;
      if (privateKey == null) {
        throw Exception("❌ PrivateKey chưa được load từ AuthService.");
      }

      final credentials = EthPrivateKey.fromHex(privateKey);
      final address = credentials.address;

      developer.log("🚀 Fetching account details for ${address.hex} ...");

      // 📡 Gọi smart contract: getUser(address)
      final result = await _web3client
          .call(
            contract: _deployedContract,
            function: _getUserFunction,
            params: [address],
          )
          .timeout(const Duration(seconds: 15));

      developer.log("🔎 Raw result from getUser: $result");

      if (result.isEmpty) {
        throw Exception("⚠️ Contract không trả về dữ liệu.");
      }

      // Contract trả về tuple: (address, string, uint8, bool)
      final userData = result.first as List;

      final EthereumAddress userAddr = userData[0] as EthereumAddress;
      final String name = userData[1] as String;
      final int roleIndex = (userData[2] as BigInt).toInt();
      final bool isInOrg = userData[3] as bool;

      developer.log(
        "📌 From contract → address=${userAddr.hex}, "
        "name=$name, roleIndex=$roleIndex, isInOrg=$isInOrg",
      );

      final String role = _mapRole(roleIndex);

      // 🔄 So sánh với Firestore (AuthService)
      developer.log(
        "🗂 From Firestore → "
        "username=${authService.value.username}, "
        "accountType=${authService.value.accountType}",
      );

      emit(
        AccountLoaded(userName: name, userAddress: userAddr.hex, role: role),
      );
    } catch (e, st) {
      developer.log("❌ Error loading account: $e", stackTrace: st);
      emit(AccountError("Failed to load account: ${e.toString()}"));
    }
  }

  String _mapRole(int roleIndex) {
    switch (roleIndex) {
      case 0:
        developer.log("🔖 Mapping roleIndex=0 → Admin");
        return "Admin";
      case 1:
        developer.log("🔖 Mapping roleIndex=1 → Organization");
        return "Organization";
      case 2:
        developer.log("🔖 Mapping roleIndex=2 → Customer");
        return "Customer";
      default:
        developer.log("⚠️ Unknown roleIndex=$roleIndex");
        return "Unknown";
    }
  }
}
