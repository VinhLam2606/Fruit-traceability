// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart';
import 'package:untitled/auth/service/auth_service.dart';
import 'package:web3dart/crypto.dart' as crypto;
import 'package:web3dart/web3dart.dart';

class RegisterPage extends StatefulWidget {
  final Function()? onTap; // Add this
  const RegisterPage({super.key, this.onTap}); // And this

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  String accountType = "user"; // default
  String errorMessage = '';
  bool _isLoading = false;

  late Web3Client ethClient;
  DeployedContract? usersContract;

  @override
  void initState() {
    super.initState();
    ethClient = Web3Client("http://10.0.2.2:7545", Client()); // Ganache
    _loadContract();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  /// 🔐 Encrypt private key with password
  String _encryptPrivateKey(String privateKey, String password) {
    final key = encrypt.Key.fromUtf8(
      password.padRight(32, '0').substring(0, 32),
    );
    final iv = encrypt.IV.fromUtf8("1234567890123456"); // fixed IV
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );

    final encrypted = encrypter.encrypt(privateKey, iv: iv);
    return encrypted.base64;
  }

  /// Load ABI + address from build/contracts/Chain.json
  Future<void> _loadContract() async {
    try {
      final abiJson = jsonDecode(
        await rootBundle.loadString("build/contracts/Users.json"),
      );
      final abi = jsonEncode(abiJson["abi"]);
      const networkId = "5777";
      final contractAddr = EthereumAddress.fromHex(
        abiJson["networks"][networkId]["address"],
      );
      usersContract = DeployedContract(
        ContractAbi.fromJson(abi, "Users"),
        contractAddr,
      );
      print("✅ Users contract loaded at $contractAddr");
    } catch (e) {
      print("⚠️ Failed to load contract: $e");
    }
  }

  Future<bool> _isBlockchainAvailable() async {
    try {
      await ethClient.getNetworkId();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Call registerUser in contract
  Future<void> _registerOnBlockchain(
    String username,
    String email,
    String walletAddr,
  ) async {
    if (usersContract == null) throw Exception("Contract not loaded");

    final registerFn = usersContract!.function("registerUser");
    final adminKey = EthPrivateKey.fromHex(
      "0xb5ae0178b193c626861663e32cef47f0c67871ea80c655ac727a642a070f45e6",
    ); // Ganache acc[0]

    await ethClient.sendTransaction(
      adminKey,
      Transaction.callContract(
        contract: usersContract!,
        function: registerFn,
        parameters: [EthereumAddress.fromHex(walletAddr), username, email],
        gasPrice: EtherAmount.inWei(BigInt.from(20000000000)),
        maxGas: 6000000,
      ),
      chainId: 1337,
    );
  }

  void register() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      if (!await _isBlockchainAvailable()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Ganache/Truffle not running")),
        );
        setState(() => _isLoading = false);
        return;
      }

      final credentials = EthPrivateKey.createRandom(Random.secure());
      final walletAddress = credentials.address.hex;
      final privateKey = crypto.bytesToHex(
        credentials.privateKey,
        include0x: true,
      );
      final encryptedKey = _encryptPrivateKey(
        privateKey,
        passwordController.text.trim(),
      );

      await _registerOnBlockchain(
        emailController.text.trim().split('@')[0],
        emailController.text.trim(),
        walletAddress,
      );

      final userCred = await authService.value.createAccount(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection("users")
          .doc(userCred.user!.uid)
          .set({
            "email": emailController.text.trim(),
            "accountType": accountType,
            "walletAddress": walletAddress,
            "privateKeyEnc": encryptedKey,
            "createdAt": FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Registered successfully")),
      );

      // No need to navigate here, AuthLayout will handle it automatically
    } catch (e) {
      setState(() => errorMessage = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Registration failed: $errorMessage")),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                        child: Text("Normal User"),
                      ),
                      DropdownMenuItem(
                        value: "organization",
                        child: Text("Organization"),
                      ),
                    ],
                    onChanged: (value) => setState(() => accountType = value!),
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
                      if (v != passwordController.text)
                        return "Passwords do not match";
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
                  // --- MODIFICATION START ---
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
                  // --- MODIFICATION END ---
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
