import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hd_wallet_kit/hd_wallet_kit.dart';
import 'package:http/http.dart' as http;
import 'package:untitled/auth/service/auth_service.dart';
import 'package:untitled/auth/service/walletExt_service.dart';
import 'package:web3dart/crypto.dart' as crypto;
import 'package:web3dart/web3dart.dart';

class RegisterPage extends StatefulWidget {
  final Function()? onTap;
  const RegisterPage({super.key, this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final usernameController = TextEditingController();

  String accountType = "user";
  String errorMessage = '';
  bool _isLoading = false;

  late Web3Client ethClient;
  DeployedContract? usersContract;

  static String providedPrivateKey = "";
  static String providedAddress = "";

  @override
  void initState() {
    super.initState();
    ethClient = Web3Client("http://10.0.2.2:7545", http.Client());
    _loadContract();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  // 🧩 Lấy tất cả tài khoản Ganache
  Future<List<String>> getGanacheAccounts() async {
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
    if (body["result"] != null) {
      return List<String>.from(body["result"]);
    }
    return [];
  }

  // 🧩 Tạo private key từ mnemonic (Ganache mặc định)
  String derivePrivateKeyFromMnemonic(String mnemonic, {int accountIndex = 0}) {
    final words = mnemonic.trim().split(RegExp(r'\s+'));
    final seed = Mnemonic.toSeed(words);
    final hdWallet = HDWallet.fromSeed(seed: seed);
    final path = "m/44'/60'/0'/0/$accountIndex";
    final derivedKey = hdWallet.deriveChildKeyByPath(path);
    return derivedKey.privateKeyHex0x;
  }

  // 🧩 Lấy tài khoản Ganache chưa dùng
  Future<void> initGanacheAccount() async {
    const mnemonic =
        "decorate foil consider depart section genuine plate person change file catch animal";

    try {
      final ganacheAccounts = await getGanacheAccounts();
      if (ganacheAccounts.isEmpty) {
        throw Exception("Không tìm thấy tài khoản Ganache nào!");
      }

      final random = Random();
      final usedAddresses = await _getUsedBlockchainAddresses();
      final shuffledIndexes = List.generate(ganacheAccounts.length, (i) => i)
        ..shuffle(random);

      for (final idx in shuffledIndexes) {
        final privateKey = derivePrivateKeyFromMnemonic(
          mnemonic,
          accountIndex: idx,
        );
        final key = EthPrivateKey.fromHex(privateKey);
        final address = await key.extractAddress();

        if (usedAddresses.contains(address.hex.toLowerCase())) continue;

        final balance = await ethClient.getBalance(address);
        if (balance.getInEther == BigInt.zero) continue;

        final alreadyRegistered = await _isUserAlreadyRegistered(address);
        if (!alreadyRegistered) {
          providedPrivateKey = privateKey;
          providedAddress = address.hex;
          print("🟢 Dùng tài khoản Ganache #$idx: $providedAddress");
          return;
        }
      }

      throw Exception("Không còn tài khoản Ganache khả dụng!");
    } catch (e) {
      print("❌ Lỗi initGanacheAccount: $e");
      rethrow;
    }
  }

  // 🧩 Lấy danh sách ví đã dùng trên Firestore
  Future<List<String>> _getUsedBlockchainAddresses() async {
    final snapshot = await FirebaseFirestore.instance.collection("users").get();
    final List<String> addresses = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data.containsKey("eth_address")) {
        final addr = data["eth_address"];
        if (addr is String && addr.isNotEmpty) {
          addresses.add(addr.toLowerCase());
        }
      }
    }
    return addresses;
  }

  // 🧩 Load ABI contract
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
      print("✅ Contract loaded at $contractAddr");
    } catch (e) {
      print("⚠️ Lỗi load contract: $e");
    }
  }

  // 🧩 Kiểm tra user đã đăng ký on-chain chưa
  Future<bool> _isUserAlreadyRegistered(EthereumAddress walletAddress) async {
    try {
      if (usersContract == null) throw Exception("Contract chưa load");
      final fn = usersContract!.function("isRegisteredAuth");
      final result = await ethClient.call(
        contract: usersContract!,
        function: fn,
        params: [walletAddress],
      );
      return result.isNotEmpty && result.first == true;
    } catch (e) {
      print("⚠️ Check registered error: $e");
      return false;
    }
  }

  Future<bool> _isBlockchainAvailable() async {
    try {
      await ethClient.getNetworkId();
      return true;
    } catch (_) {
      return false;
    }
  }

  // 🧩 Ghi user lên blockchain
  Future<String> _registerOnBlockchain(
    String username,
    String email,
    EthPrivateKey senderKey,
    EthereumAddress walletAddress,
  ) async {
    if (usersContract == null) throw Exception("Contract not loaded");
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
    print("👤 Blockchain: registerUser txHash=$txHash");
    return txHash;
  }

  // 🧩 Ghi tổ chức lên blockchain
  Future<String> _addOrganization(
    String orgName,
    EthPrivateKey senderKey,
  ) async {
    if (usersContract == null) throw Exception("Contract not loaded");
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
    print("🏢 Blockchain: addOrganization txHash=$txHash");
    return txHash;
  }

  Future<void> _waitForTx(String txHash) async {
    print("⏳ Waiting for tx $txHash...");
    while (true) {
      final receipt = await ethClient.getTransactionReceipt(txHash);
      if (receipt != null) {
        print("✅ Tx mined: $txHash");
        break;
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  // 🧩 Đăng ký tài khoản (Firebase + Blockchain)
  void register() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    setState(() => _isLoading = true);

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final username = usernameController.text.trim();

    try {
      if (!await _isBlockchainAvailable()) {
        throw Exception("Không thể kết nối tới Ganache!");
      }

      await initGanacheAccount();

      final firebaseUser = await authService.value.createAccount(
        email: email,
        password: password,
      );

      final credentials = EthPrivateKey.fromHex(providedPrivateKey);
      final walletAddress = EthereumAddress.fromHex(providedAddress);
      final pKeyHex = crypto.bytesToHex(
        credentials.privateKey,
        include0x: true,
      );
      final ethAddressHex = walletAddress.hex.toLowerCase();

      final regTx = await _registerOnBlockchain(
        username,
        email,
        credentials,
        walletAddress,
      );
      await _waitForTx(regTx);

      String roleToSave = "Customer";
      bool orgDetailsSubmitted = true; // Mặc định là true cho 'user'

      if (accountType == "organization") {
        final orgTx = await _addOrganization("${username}_org", credentials);
        await _waitForTx(orgTx);
        print("🏢 Created organization for $username (role=Manufacturer)");
        roleToSave = "Manufacturer";
        orgDetailsSubmitted = false; // 🔥 ĐẶT LÀ FALSE KHI TẠO ORG
      }

      // 🔥 TẠO MAP DỮ LIỆU
      final Map<String, dynamic> userData = {
        "username": username,
        "email": email,
        "role": roleToSave,
        "accountType": accountType,
        "eth_address": ethAddressHex,
        "private_key": pKeyHex,
        "createdAt": FieldValue.serverTimestamp(),
        "isOrganizationDetailsSubmitted": orgDetailsSubmitted,
      };

      // 🔥 Ghi vào Firestore
      await FirebaseFirestore.instance
          .collection("users")
          .doc(firebaseUser.user!.uid)
          .set(userData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Đăng ký $roleToSave thành công!")),
      );

      // 🔥🔥 SỬA LỖI: CẬP NHẬT AUTHSERVICE NGAY LẬP TỨC 🔥🔥
      // Điều này sẽ kích hoạt AuthLayout rebuild với dữ liệu MỚI NHẤT
      authService.value.userData = {
        "username": username,
        "accountType": accountType,
        "eth_address": ethAddressHex,
        "private_key": pKeyHex,
        "isOrganizationDetailsSubmitted": orgDetailsSubmitted,
      };
      authService.notifyListeners();
    } catch (e) {
      print("❌ Lỗi đăng ký: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Lỗi: $e")));
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.delete();
        print("🧹 Firebase user deleted due to blockchain failure.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- UI ------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF141E30), Color(0xFF243B55)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 28.0,
                vertical: 20,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 90,
                      color: Colors.greenAccent,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Create Account ✨",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Join the blockchain-powered system",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 40),

                    // Account type
                    DropdownButtonFormField<String>(
                      initialValue: accountType,
                      dropdownColor: Colors.black,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Account Type"),
                      items: const [
                        DropdownMenuItem(
                          value: "user",
                          child: Text("Normal User (Customer)"),
                        ),
                        DropdownMenuItem(
                          value: "organization",
                          child: Text("Organization (Manufacturer)"),
                        ),
                      ],
                      onChanged: (v) => setState(() => accountType = v!),
                    ),
                    const SizedBox(height: 20),

                    // Username
                    TextFormField(
                      controller: usernameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Username"),
                      validator: (v) =>
                          v == null || v.isEmpty ? "Enter username" : null,
                    ),
                    const SizedBox(height: 20),

                    // Email
                    TextFormField(
                      controller: emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Email"),
                      validator: (v) =>
                          v == null || v.isEmpty ? "Enter email" : null,
                    ),
                    const SizedBox(height: 20),

                    // Password
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Password"),
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Enter password";
                        if (v.length < 6) return "Password must be >= 6 chars";
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Confirm Password
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Confirm Password"),
                      validator: (v) {
                        if (v != passwordController.text) {
                          return "Passwords do not match";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 35),

                    // Register button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 10,
                          shadowColor: Colors.greenAccent.withOpacity(0.5),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                "REGISTER",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: const [
                        Expanded(
                          child: Divider(color: Colors.white24, thickness: 1),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            "OR",
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: Colors.white24, thickness: 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),

                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: "Already have an account? ",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: "Login now",
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = widget.onTap,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.greenAccent, width: 2),
      ),
    );
  }
}
