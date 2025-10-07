import 'dart:convert';
import 'dart:developer' as developer;

import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:web3dart/web3dart.dart';

import '../model/organization.dart';

part 'user_organization_event.dart';
part 'user_organization_state.dart';

class UserOrganizationBloc
    extends Bloc<UserOrganizationEvent, UserOrganizationState> {
  final Web3Client web3client;
  final EthPrivateKey credentials;

  late DeployedContract deployedContract;
  bool _isContractLoaded = false;

  // Các hàm trong Smart Contract
  late ContractFunction _getOrganizationByMemberFunction;
  late ContractFunction _leaveOrganizationFunction;

  UserOrganizationBloc({required this.web3client, required this.credentials})
    : super(UserOrganizationInitial()) {
    on<FetchUserOrganization>(_onFetchUserOrganization);
    on<LeaveOrganization>(_onLeaveOrganization);
  }

  /// ✅ Load contract và ánh xạ các hàm
  Future<void> _initializeContract() async {
    if (_isContractLoaded) return;

    final abiString = await rootBundle.loadString("build/contracts/Chain.json");
    final jsonAbi = jsonDecode(abiString);

    if (!jsonAbi.containsKey('abi') || !jsonAbi.containsKey('networks')) {
      throw Exception("❌ ABI file invalid: missing 'abi' or 'networks'.");
    }

    final abi = ContractAbi.fromJson(jsonEncode(jsonAbi['abi']), 'Chain');
    final networks = jsonAbi['networks'] as Map<String, dynamic>;
    if (networks.isEmpty) {
      throw Exception("❌ No network found in ABI file.");
    }

    final networkKey = networks.keys.first;
    final contractAddressHex = networks[networkKey]['address'] as String?;
    if (contractAddressHex == null || contractAddressHex.isEmpty) {
      throw Exception("❌ Missing contract address.");
    }

    final contractAddress = EthereumAddress.fromHex(contractAddressHex);
    deployedContract = DeployedContract(abi, contractAddress);

    _getOrganizationByMemberFunction = deployedContract.function(
      'getOrganizationByMember',
    );
    _leaveOrganizationFunction = deployedContract.function('leaveOrganization');

    _isContractLoaded = true;
    developer.log("📦 Contract loaded at $contractAddress");
  }

  /// ✅ Lấy thông tin tổ chức hiện tại
  Future<void> _onFetchUserOrganization(
    FetchUserOrganization event,
    Emitter<UserOrganizationState> emit,
  ) async {
    emit(UserOrganizationLoading());
    try {
      await _initializeContract();

      final result = await web3client.call(
        contract: deployedContract,
        function: _getOrganizationByMemberFunction,
        params: [credentials.address],
      );

      if (result.isEmpty || result.first is! List<dynamic>) {
        emit(UserOrganizationError("Invalid contract response"));
        return;
      }

      final rawOrg = result.first as List<dynamic>;
      final EthereumAddress ownerAddress = rawOrg[2] as EthereumAddress;
      const zeroAddress = "0x0000000000000000000000000000000000000000";

      if (ownerAddress.hex.toLowerCase() == zeroAddress) {
        emit(UserOrganizationEmpty());
        return;
      }

      final org = Organization.fromContract(rawOrg);
      emit(UserOrganizationLoaded(org));
    } catch (e) {
      developer.log("❌ Fetch organization failed", error: e);
      emit(UserOrganizationError("Error: ${e.toString()}"));
    }
  }

  /// ✅ Rời tổ chức (fix cho web3dart cũ)
  Future<void> _onLeaveOrganization(
    LeaveOrganization event,
    Emitter<UserOrganizationState> emit,
  ) async {
    try {
      developer.log("📤 Preparing to leave organization...");
      emit(UserOrganizationLoading());
      await _initializeContract();

      developer.log("📜 Contract ready, calling leaveOrganization()...");

      // ✅ Không dùng TransactionType, fix cho web3dart cũ
      final tx = Transaction.callContract(
        contract: deployedContract,
        function: _leaveOrganizationFunction,
        parameters: [],
        maxGas: 200000,
      );

      // ✅ Ganache cần set chainId thủ công để tránh lỗi chữ ký
      final txHash = await web3client.sendTransaction(
        credentials,
        tx,
        chainId: 1337, // Default chainId của Ganache
        fetchChainIdFromNetworkId: false,
      );

      developer.log("🚀 LeaveOrganization transaction hash: $txHash");

      // ✅ Thông báo rời tổ chức thành công
      emit(UserOrganizationLeftSuccess("You have left the organization."));

      // ✅ Fetch lại tổ chức sau khi rời
      add(FetchUserOrganization());
    } catch (e) {
      developer.log("❌ LeaveOrganization failed", error: e);
      emit(UserOrganizationError("Cannot leave organization: ${e.toString()}"));
    }
  }
}
