// ignore_for_file: avoid_print, use_build_context_synchronously, deprecated_member_use

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

  String accountType = "user";
  String errorMessage = '';
  bool _isLoading = false;

  late Web3Client ethClient;
  DeployedContract? usersContract;

  static const providedPrivateKey =
      "0xebd4ba780d7875ea3e168960340f151e00356916d1e90aef4426469d1cdc2620";
  static const providedAddress = "0x1B40fC3BaBf04Ee400f093D1405944E8fC70c599";

  @override
  void initState() {
    super.initState();
    ethClient = Web3Client("http://10.0.2.2:7545", Client());
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
    EthereumAddress walletAddress,
  ) async {
    if (usersContract == null) throw Exception("Contract not loaded");
    final registerFn = usersContract!.function("registerUser");
    final txHash = await ethClient.sendTransaction(
      senderKey,
      Transaction.callContract(
        contract: usersContract!,
        function: registerFn,
        parameters: [walletAddress, email],
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
          BigInt.from(DateTime.now().millisecondsSinceEpoch),
        ],
      ),
      chainId: 1337,
    );
    print("🏢 Blockchain: addOrganization txHash=$txHash");
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
      print("🔎 Registering for $username ($accountType)...");

      final regTx = await _registerOnBlockchain(
        username,
        email,
        credentials,
        walletAddress,
      );
      await _waitForTx(regTx);

      String roleToSave = "Customer";
      if (accountType == "organization") {
        final orgTx = await _addOrganization("${username}_org", credentials);
        await _waitForTx(orgTx);
        print("✅ Created organization for $username (role=Manufacturer)");
        roleToSave = "Manufacturer";
      }

      final userCred = await authService.value.createAccount(
        email: email,
        password: password,
      );

      await FirebaseFirestore.instance
          .collection("users")
          .doc(userCred.user!.uid)
          .set({
            "username": username,
            "email": email,
            "role": roleToSave,
            "accountType": accountType,
            "eth_address": walletAddress.hex,
            "private_key": crypto.bytesToHex(
              credentials.privateKey,
              include0x: true,
            ),
            "createdAt": FieldValue.serverTimestamp(),
          });

      print("🎉 Registration successful (role=$roleToSave)");
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

                    // Account type dropdown
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
                      onChanged: (value) =>
                          setState(() => accountType = value!),
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

                    // Confirm password
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

                    // 🔙 Back to Login button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: widget.onTap,
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.greenAccent,
                        ),
                        label: const Text(
                          "Back to Login",
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.greenAccent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

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
