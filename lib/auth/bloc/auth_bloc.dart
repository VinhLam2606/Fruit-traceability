// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:untitled/auth/service/walletExt_service.dart';
import 'package:web3dart/web3dart.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hd_wallet_kit/hd_wallet_kit.dart';
import 'package:web3dart/crypto.dart' as crypto;

import '../service/auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;

  late Web3Client ethClient;
  DeployedContract? usersContract;

  static String providedPrivateKey = "";
  static String providedAddress = "";

  AuthBloc(this._authService) : super(AuthInitial()) {
    ethClient = Web3Client("http://10.0.2.2:7545", http.Client());
    _loadContract();

    on<AuthStarted>(_onAuthStarted);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthForgotPasswordRequested>(_onForgotPasswordRequested);
  }

  Future<void> _initGanacheAccount() async {
    const mnemonic =
        "empower ocean injury exchange diesel hub veteran athlete cake resist hurdle response";

    final ganacheAccounts = await _getGanacheAccounts();
    if (ganacheAccounts.isEmpty) {
      throw Exception("Ganache RPC returned no accounts.");
    }

    for (int i = 0; i < 10; i++) {
      final derivedKey = _derivePrivateKeyFromMnemonic(mnemonic, i);
      final credentials = EthPrivateKey.fromHex(derivedKey);
      final address = await credentials.extractAddress();

      final balance = await ethClient.getBalance(address);
      if (balance.getInEther == BigInt.zero) continue;

      final alreadyRegistered = await _isUserAlreadyRegistered(address);
      if (!alreadyRegistered) {
        providedPrivateKey = derivedKey;
        providedAddress = address.hex;
        print("🟢 Selected funded account #$i: $providedAddress");
        return;
      }
    }
    throw Exception("No funded & unregistered Ganache accounts available!");
  }

  Future<void> _onAuthStarted(
    AuthStarted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthInitial());
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      print("🔑 [AuthBloc] Logging in user with email: ${event.email}");
      await _authService.signIn(email: event.email, password: event.password);

      print("✅ [AuthBloc] Login successful for: ${_authService.username}");
      print("🪪 Wallet: ${_authService.walletAddress}");
      print("👤 Account Type: ${_authService.accountType}");

      emit(
        AuthSuccess(
          username: _authService.username ?? '',
          walletAddress: _authService.walletAddress ?? '',
          accountType: _authService.accountType ?? '',
        ),
      );

      print("✨ [AuthBloc] Welcome back, ${_authService.username ?? 'User'}!");
    } catch (e) {
      print("❌ [AuthBloc] Login failed: $e");
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authService.signOut();
    emit(AuthLoggedOut());
  }

  Future<void> _onForgotPasswordRequested(
      AuthForgotPasswordRequested event,
      Emitter<AuthState> emit,
      ) async {
    emit(AuthLoading());
    try {
      print("📧 [AuthBloc] Requesting password reset for: ${event.email}");

      // Gọi hàm từ AuthService
      await _authService.sendPasswordResetEmail(email: event.email);

      print("✅ [AuthBloc] Password reset email sent successfully.");

      // Phát ra State thông báo thành công cho UI
      emit(AuthPasswordResetEmailSent(event.email));
    } catch (e) {
      print("❌ [AuthBloc] Password reset failed: $e");
      // Phát ra State thất bại
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      // 1️⃣ Init Ganache & contract
      await _loadContract();
      await _initGanacheAccount();

      if (usersContract == null) throw Exception("Contract not loaded");

      final isOk = await _isBlockchainAvailable();
      if (!isOk) throw Exception("Ganache RPC unavailable");

      final credentials = EthPrivateKey.fromHex(providedPrivateKey);
      final walletAddress = EthereumAddress.fromHex(providedAddress);

      // 2️⃣ Check if user already registered on-chain
      final alreadyExists = await _isUserAlreadyRegistered(walletAddress);
      if (alreadyExists) {
        throw Exception("User already registered on blockchain!");
      }

      // 3️⃣ Register user on blockchain
      final txHash = await _registerOnBlockchain(
        event.username,
        event.email,
        credentials,
        walletAddress,
      );
      await _waitForTx(txHash);

      // 4️⃣ If organization, also create org on-chain
      String role = "Customer";
      if (event.accountType == "organization") {
        final orgTx = await _addOrganization(
          "${event.username}_org",
          credentials,
        );
        await _waitForTx(orgTx);
        role = "Manufacturer";
      }

      // 5️⃣ Register on Firebase
      final userCred = await _authService.createAccount(
        email: event.email,
        password: event.password,
      );

      // 6️⃣ Save Firestore record
      await FirebaseFirestore.instance
          .collection("users")
          .doc(userCred.user!.uid)
          .set({
            "username": event.username,
            "email": event.email,
            "role": role,
            "accountType": event.accountType,
            "eth_address": walletAddress.hex,
            "private_key": crypto.bytesToHex(
              credentials.privateKey,
              include0x: true,
            ),
            "createdAt": FieldValue.serverTimestamp(),
          });

      print("🎉 Registration completed successfully!");
      emit(
        AuthSuccess(
          username: event.username,
          walletAddress: providedAddress,
          accountType: event.accountType,
        ),
      );
    } catch (e) {
      print("❌ Registration failed: $e");
      emit(AuthFailure(e.toString()));

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.delete();
        print("🧹 Firebase user deleted after failed blockchain registration.");
      }
    }
  }

  // ------------------------------------------------------------
  // 🔹 Blockchain helper methods
  // ------------------------------------------------------------
  Future<void> _loadContract() async {
    try {
      final abiJson = jsonDecode(
        await rootBundle.loadString("build/contracts/Chain.json"),
      );
      final abi = jsonEncode(abiJson["abi"]);
      const networkId = "5777";
      final contractAddr = EthereumAddress.fromHex(
        abiJson["networks"][networkId]["address"],
      );
      usersContract = DeployedContract(
        ContractAbi.fromJson(abi, "Chain"),
        contractAddr,
      );
      print("✅ Chain contract loaded at $contractAddr");
    } catch (e) {
      print("⚠️ Failed to load contract: $e");
    }
  }

  Future<List<String>> _getGanacheAccounts() async {
    final res = await http.post(
      Uri.parse("http://10.0.2.2:7545"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "jsonrpc": "2.0",
        "method": "eth_accounts",
        "params": [],
        "id": 1,
      }),
    );
    final body = jsonDecode(res.body);
    return body["result"] != null ? List<String>.from(body["result"]) : [];
  }

  String _derivePrivateKeyFromMnemonic(String mnemonic, int index) {
    final words = mnemonic.trim().split(RegExp(r'\s+'));
    final seed = Mnemonic.toSeed(words);
    final hdWallet = HDWallet.fromSeed(seed: seed);
    final path = "m/44'/60'/0'/0/$index";
    final derivedKey = hdWallet.deriveChildKeyByPath(path);
    return derivedKey.privateKeyHex0x;
  }

  Future<bool> _isBlockchainAvailable() async {
    try {
      await ethClient.getNetworkId();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _isUserAlreadyRegistered(EthereumAddress address) async {
    if (usersContract == null) return false;
    final fn = usersContract!.function("isRegisteredAuth");
    final result = await ethClient.call(
      contract: usersContract!,
      function: fn,
      params: [address],
    );
    return result.isNotEmpty && result.first == true;
  }

  Future<String> _registerOnBlockchain(
    String username,
    String email,
    EthPrivateKey senderKey,
    EthereumAddress walletAddress,
  ) async {
    final fn = usersContract!.function("registerUser");
    final txHash = await ethClient.sendTransaction(
      senderKey,
      Transaction.callContract(
        contract: usersContract!,
        function: fn,
        parameters: [walletAddress, email],
      ),
      chainId: 1337,
    );
    print("👤 registerUser tx: $txHash");
    return txHash;
  }

  Future<String> _addOrganization(
    String orgName,
    EthPrivateKey senderKey,
  ) async {
    final fn = usersContract!.function("addOrganization");
    final txHash = await ethClient.sendTransaction(
      senderKey,
      Transaction.callContract(
        contract: usersContract!,
        function: fn,
        parameters: [
          orgName,
          BigInt.from(DateTime.now().millisecondsSinceEpoch),
        ],
      ),
      chainId: 1337,
    );
    print("🏢 addOrganization tx: $txHash");
    return txHash;
  }

  Future<void> _waitForTx(String txHash) async {
    print("⏳ Waiting for tx $txHash to be mined...");
    while (true) {
      final receipt = await ethClient.getTransactionReceipt(txHash);
      if (receipt != null) {
        print("✅ Tx mined: $txHash");
        break;
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }
}
