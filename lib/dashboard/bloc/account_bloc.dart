import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

part 'account_event.dart';
part 'account_state.dart';

class AccountBloc extends Bloc<AccountEvent, AccountState> {
  late Web3Client _web3client;
  late DeployedContract _deployedContract;
  late EthPrivateKey _credentials;
  late ContractFunction _getUserFunction;

  AccountBloc() : super(AccountInitial()) {
    on<FetchAccountDetails>(_onFetchAccountDetails);
  }

  Future<void> _initWeb3() async {
    const String rpcUrl = "http://10.0.2.2:7545";
    const String privateKey =
        "YOUR_PRIVATE_KEY"; // THAY BẰNG PRIVATE KEY CỦA BẠN

    _web3client = Web3Client(rpcUrl, http.Client());
    final abiString = await rootBundle.loadString("build/contracts/Chain.json");
    final jsonAbi = jsonDecode(abiString);
    final abi = ContractAbi.fromJson(jsonEncode(jsonAbi['abi']), 'Chain');
    final networkKey = (jsonAbi['networks'] as Map<String, dynamic>).keys.first;
    final contractAddress = EthereumAddress.fromHex(
      jsonAbi['networks'][networkKey]['address'],
    );

    _credentials = EthPrivateKey.fromHex(privateKey);
    _deployedContract = DeployedContract(abi, contractAddress);
    _getUserFunction = _deployedContract.function('getUser');
  }

  FutureOr<void> _onFetchAccountDetails(
    FetchAccountDetails event,
    Emitter<AccountState> emit,
  ) async {
    emit(AccountLoading());
    try {
      await _initWeb3();
      final address = await _credentials.extractAddress();
      final result = await _web3client.call(
        contract: _deployedContract,
        function: _getUserFunction,
        params: [address],
      );

      final userData = result[0];
      final String name = userData[1];
      final BigInt roleIndex = userData[2];
      final String role = _mapRole(roleIndex.toInt());

      emit(AccountLoaded(userName: name, userAddress: address.hex, role: role));
    } catch (e) {
      emit(AccountError("Failed to load account details: ${e.toString()}"));
    }
  }

  String _mapRole(int roleIndex) {
    switch (roleIndex) {
      case 0:
        return "Admin";
      case 1:
        return "Manufacturer";
      case 2:
        return "Customer";
      default:
        return "Unknown";
    }
  }
}
