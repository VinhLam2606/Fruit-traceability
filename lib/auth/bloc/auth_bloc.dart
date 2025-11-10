// ignore_for_file: avoid_print, unused_element

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
    ethClient = Web3Client("http://192.168.102.5:7545", http.Client());
    _loadContract();

    on<AuthStarted>(_onAuthStarted);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthEmailVerificationChecked>(_onEmailVerificationChecked);
    on<AuthForgotPasswordRequested>(_onForgotPasswordRequested);
  }

  // ---------------------------------------------------------
  // AUTH STARTUP
  // ---------------------------------------------------------
  Future<void> _onAuthStarted(
    AuthStarted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthInitial());
  }

  // ---------------------------------------------------------
  // LOGIN
  // ---------------------------------------------------------
  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      print("🔑 [AuthBloc] Logging in: ${event.email}");
      final userCred = await _authService.signIn(
        email: event.email,
        password: event.password,
      );

      // kiểm tra xác thực email
      await userCred.user?.reload();
      if (!(userCred.user?.emailVerified ?? false)) {
        emit(AuthFailure("Email not verified. Please check your inbox."));
        await _authService.signOut();
        return;
      }

      emit(
        AuthSuccess(
          username: _authService.username ?? '',
          walletAddress: _authService.walletAddress ?? '',
          accountType: _authService.accountType ?? '',
        ),
      );
      print("✅ Login successful: ${_authService.username}");
    } catch (e) {
      print("❌ Login failed: $e");
      emit(AuthFailure(e.toString()));
    }
  }

  // ---------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------
  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authService.signOut();
    emit(AuthLoggedOut());
  }

  // ---------------------------------------------------------
  // FORGOT PASSWORD
  // ---------------------------------------------------------
  Future<void> _onForgotPasswordRequested(
    AuthForgotPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.sendPasswordResetEmail(email: event.email);
      emit(AuthPasswordResetEmailSent(event.email));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  // ---------------------------------------------------------
  // REGISTER PHASE 1 — Firebase only
  // ---------------------------------------------------------
  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      print("🆕 [AuthBloc] Creating Firebase account for ${event.email}");
      final userCred = await _authService.createAccount(
        email: event.email,
        password: event.password,
      );

      await FirebaseFirestore.instance
          .collection("pending_users")
          .doc(userCred.user!.uid)
          .set({
            "email": event.email,
            "username": event.username,
            "accountType": event.accountType,
            "createdAt": FieldValue.serverTimestamp(),
          });

      await _authService.sendEmailVerification(userCred.user!);
      print("📩 Verification email sent → waiting for confirmation");

      emit(AuthEmailVerificationPending(email: event.email));
    } catch (e) {
      print("❌ Registration failed: $e");
      emit(AuthFailure(e.toString()));

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.delete();
        print("🧹 Deleted unverified Firebase user");
      }
    }
  }

  // ---------------------------------------------------------
  // REGISTER PHASE 2 — After email verification
  // ---------------------------------------------------------
  Future<void> _onEmailVerificationChecked(
    AuthEmailVerificationChecked event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final verified = await _authService.isEmailVerified();

      if (!verified) {
        emit(AuthFailure("Email not verified yet. Please check your inbox."));
        return;
      }

      print("✅ Email verified → start blockchain + Firestore setup...");

      // 1️⃣ Đọc lại thông tin accountType + username nếu bị mất
      String accType = event.accountType;
      String uname = event.username;

      final currentUser = FirebaseAuth.instance.currentUser!;
      final pendingDoc = await FirebaseFirestore.instance
          .collection("pending_users")
          .doc(currentUser.uid)
          .get();

      if ((accType.isEmpty || uname.isEmpty) && pendingDoc.exists) {
        accType = pendingDoc.data()?["accountType"] ?? "user";
        uname =
            pendingDoc.data()?["username"] ??
            currentUser.email?.split("@").first ??
            "User";
        print(
          "ℹ️ [AuthBloc] Recovered accountType=$accType, username=$uname from pending_users",
        );
      }

      // 2️⃣ Init Ganache + Contract
      await _loadContract();
      await _initGanacheAccount();

      if (usersContract == null) throw Exception("Contract not loaded");
      final credentials = EthPrivateKey.fromHex(providedPrivateKey);
      final walletAddress = EthereumAddress.fromHex(providedAddress);

      // 3️⃣ Check duplicate blockchain user
      final alreadyExists = await _isUserAlreadyRegistered(walletAddress);
      if (alreadyExists) throw Exception("User already exists on blockchain!");

      // 4️⃣ Register on blockchain
      final txHash = await _registerOnBlockchain(
        currentUser.email ?? '',
        currentUser.email ?? '',
        credentials,
        walletAddress,
      );
      await _waitForTx(txHash);

      // 5️⃣ Save to Firestore (users)
      await FirebaseFirestore.instance
          .collection("users")
          .doc(currentUser.uid)
          .set({
            "email": currentUser.email,
            "username": uname,
            "role": accType == "organization" ? "Manufacturer" : "Customer",
            "accountType": accType,
            "eth_address": walletAddress.hex,
            "private_key": crypto.bytesToHex(
              credentials.privateKey,
              include0x: true,
            ),
            "createdAt": FieldValue.serverTimestamp(),
            "isOrganizationDetailsSubmitted": accType == "organization"
                ? false
                : true,
          });

      // 6️⃣ Xoá dữ liệu tạm
      await FirebaseFirestore.instance
          .collection("pending_users")
          .doc(currentUser.uid)
          .delete()
          .catchError((_) => print("⚠️ Không tìm thấy pending_users để xoá."));

      print("🎉 Registration finalized successfully! -> type: $accType");

      // 7️⃣ Phát sự kiện thành công
      emit(
        AuthSuccess(
          username: uname,
          walletAddress: walletAddress.hex,
          accountType: accType,
        ),
      );

      if (accType == "organization") {
        print("🏭 Redirecting to OrganizationFormPage...");
      } else {
        print("👤 Normal user registered successfully.");
      }
    } catch (e) {
      print("❌ Email verification completion failed: $e");
      emit(AuthFailure(e.toString()));
    }
  }

  // ---------------------------------------------------------
  // 🔹 Blockchain Helper Methods
  // ---------------------------------------------------------
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

  Future<void> _initGanacheAccount() async {
    const mnemonic =
        "ecology minimum unusual wall spatial lyrics gaze bundle waste aunt scissors sausage";

    final ganacheAccounts = await _getGanacheAccounts();
    if (ganacheAccounts.isEmpty) throw Exception("No Ganache accounts found.");

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

  Future<List<String>> _getGanacheAccounts() async {
    final res = await http.post(
      Uri.parse("http://192.168.102.5:7545"),
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
