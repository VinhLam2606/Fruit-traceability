// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart'; // Add this import
import 'package:http/http.dart';
import 'package:untitled/auth/service/auth_service.dart';
import 'package:untitled/dashboard/bloc/dashboard_bloc.dart'; // Add this import
import 'package:untitled/navigation/main_navigation.dart'; // Add this import
import 'package:web3dart/crypto.dart' as crypto;
import 'package:web3dart/web3dart.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

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

    print("🔑 Plain private key: $privateKey");
    print("🔒 Encrypted (Base64): ${encrypted.base64}");

    return encrypted.base64;
  }

  /// Load ABI + address from build/contracts/Chain.json
  Future<void> _loadContract() async {
    try {
      final abiJson = jsonDecode(
        await rootBundle.loadString("build/contracts/Users.json"),
      );

      final abi = jsonEncode(abiJson["abi"]);
      final networkId = "5777";
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
      final netVersion = await ethClient.getNetworkId();
      print("✅ Connected to network $netVersion");
      return true;
    } catch (e) {
      print("❌ Blockchain unavailable: $e");
      return false;
    }
  }

  /// Call registerUser in contract
  Future<void> _registerOnBlockchain(
    String username,
    String email,
    String walletAddr,
  ) async {
    if (usersContract == null) {
      throw Exception("Contract not loaded");
    }

    final registerFn = usersContract!.function("registerUser");

    final adminKey = EthPrivateKey.fromHex(
      "0xb5ae0178b193c626861663e32cef47f0c67871ea80c655ac727a642a070f45e6", // Ganache acc[0]
    );

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
    if (!_formKey.currentState!.validate()) return;

    try {
      if (!await _isBlockchainAvailable()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Ganache/Truffle not running")),
        );
        return;
      }

      // Generate wallet
      final credentials = EthPrivateKey.createRandom(Random.secure());
      final walletAddress = credentials.address.hex;
      final privateKey = crypto.bytesToHex(
        credentials.privateKey,
        include0x: true,
      );
      print("➡ Wallet generated: $walletAddress");

      final encryptedKey = _encryptPrivateKey(
        privateKey,
        passwordController.text.trim(),
      );

      // Register on blockchain
      await _registerOnBlockchain(
        emailController.text.trim().split('@')[0],
        emailController.text.trim(),
        walletAddress,
      );

      // Firebase Auth
      final userCred = await authService.value.createAccount(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Firestore
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

      // --- MODIFICATION START ---
      // Navigate to MainNavigationPage, providing it with a DashboardBloc.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (context) =>
                DashboardBloc()..add(DashboardInitialFetchEvent()),
            child: const MainNavigationPage(),
          ),
        ),
      );
      // --- MODIFICATION END ---
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Registration failed: $errorMessage")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Fruit Traceability",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
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
                  value: accountType, // Use value instead of initialValue
                  dropdownColor: Colors.black,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Account Type"),
                  items: const [
                    DropdownMenuItem(value: "user", child: Text("Normal User")),
                    DropdownMenuItem(
                      value: "organization",
                      child: Text("Organization"),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      accountType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Email"),
                  validator: (value) =>
                      value == null || value.isEmpty ? "Enter email" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Password"),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Enter password";
                    }
                    if (value.length < 6) {
                      return "Password must be >= 6 chars";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Confirm Password"),
                  validator: (value) {
                    if (value != passwordController.text) {
                      return "Passwords do not match";
                    }
                    return null;
                  },
                ),
                const Spacer(),
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
                    child: const Text(
                      "Register",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
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
        borderSide: BorderSide.none, // remove the default border
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
