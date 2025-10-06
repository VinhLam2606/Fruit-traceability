import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart';
import 'package:untitled/auth/service/auth_service.dart';
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

  String accountType = "user"; // default = Customer
  String errorMessage = '';
  bool _isLoading = false;

  late Web3Client ethClient;
  DeployedContract? usersContract;

  // 🔑 Hardcode key Ganache để test
  static const providedPrivateKey =
      "0x19068590c554fbfb02d4a9095ee7f4ca6e3ccbe6c9984964efd1d576553c0f0c";
  static const providedAddress = "0xAF51F6558D90F738366296E2a8fc20fFf854B6cf";

  @override
  void initState() {
    super.initState();
    ethClient = Web3Client("http://10.0.2.2:7545", Client()); // Ganache local
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

  Future<void> _loadContract() async {
    try {
      final abiJson = jsonDecode(
        await rootBundle.loadString("build/contracts/Chain.json"),
      );
      final abi = jsonEncode(abiJson["abi"]);
      const networkId = "5777"; // Ganache default
      final contractAddr = EthereumAddress.fromHex(
        abiJson["networks"][networkId]["address"],
      );
      usersContract = DeployedContract(
        ContractAbi.fromJson(abi, "Chain"), // 👈 tên contract là Chain
        contractAddr,
      );
      print("✅ Chain contract loaded at $contractAddr");
    } catch (e) {
      print("⚠️ Failed to load contract: $e");
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

  Future<String> _registerOnBlockchain(
    String username,
    String email,
    EthPrivateKey senderKey,
  ) async {
    if (usersContract == null) throw Exception("Contract not loaded");

    final registerFn = usersContract!.function("registerUser");

    final txHash = await ethClient.sendTransaction(
      senderKey,
      Transaction.callContract(
        contract: usersContract!,
        function: registerFn,
        parameters: [username, email],
      ),
      chainId: 1337,
    );

    print("👤 Blockchain: registerUser txHash=$txHash");
    return txHash;
  }

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
          BigInt.from(
            DateTime.now().millisecondsSinceEpoch,
          ), // ✅ sửa thành BigInt
        ],
      ),
      chainId: 1337,
    );

    print("🏢 Blockchain: addOrganization txHash=$txHash");
    return txHash;
  }

  Future<void> _waitForTx(String txHash) async {
    print("⏳ Đang chờ tx $txHash được mined...");
    while (true) {
      final receipt = await ethClient.getTransactionReceipt(txHash);
      if (receipt != null) {
        print("✅ Tx mined: $txHash");
        break;
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  void register() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    setState(() => _isLoading = true);

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final username = usernameController.text.trim();

    try {
      if (!await _isBlockchainAvailable()) {
        throw Exception("Không thể kết nối đến Ganache.");
      }

      final credentials = EthPrivateKey.fromHex(providedPrivateKey);
      final walletAddress = EthereumAddress.fromHex(providedAddress);

      print("🔎 Bắt đầu đăng ký cho $username ($accountType)...");

      // 1. Đăng ký user trên Blockchain (mặc định Customer)
      final regTx = await _registerOnBlockchain(username, email, credentials);
      await _waitForTx(regTx);

      String roleToSave = "Customer";

      // 2. Nếu là Organization thì gọi thêm addOrganization để nâng role
      if (accountType == "organization") {
        final orgTx = await _addOrganization("${username}_org", credentials);
        await _waitForTx(orgTx);
        print("✅ Đã tạo tổ chức cho $username (role=Manufacturer)");
        roleToSave = "Manufacturer";
      } else {
        print("✅ Đăng ký User thường (role=Customer): $username");
      }

      // 3. Đăng ký Firebase Auth
      final userCred = await authService.value.createAccount(
        email: email,
        password: password,
      );

      // 4. Lưu Firestore với role chuẩn xác
      await FirebaseFirestore.instance
          .collection("users")
          .doc(userCred.user!.uid)
          .set({
            "username": username,
            "email": email,
            "role": roleToSave,
            "accountType": accountType, // 🔑 Lưu đúng role
            "eth_address": walletAddress.hex,
            "private_key": crypto.bytesToHex(
              credentials.privateKey,
              include0x: true,
            ),
            "createdAt": FieldValue.serverTimestamp(),
          });

      print("🎉 Đăng ký thành công (role=$roleToSave)");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Đăng ký $roleToSave thành công!")),
        );
      }
    } catch (e) {
      setState(() => errorMessage = e.toString());
      print("❌ Lỗi đăng ký: $errorMessage");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Lỗi đăng ký: $errorMessage")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  const Text(
                    "Create Account",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),
                  DropdownButtonFormField<String>(
                    value: accountType,
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
                    onChanged: (value) => setState(() => accountType = value!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: usernameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Username"),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Enter username" : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Email"),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Enter email" : null,
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 30),
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
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              "Register",
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  RichText(
                    text: TextSpan(
                      text: "Already have an account? ",
                      style: const TextStyle(color: Colors.white54),
                      children: [
                        TextSpan(
                          text: "Login now",
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = widget.onTap,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
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
      hintStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.black45,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.greenAccent),
      ),
    );
  }
}
