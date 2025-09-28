// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:untitled/auth/service/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:web3dart/web3dart.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:untitled/auth/ui/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String errorMessage = '';

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// 🔓 Decrypt private key with password
  String _decryptPrivateKey(String encryptedKey, String password) {
    final key = encrypt.Key.fromUtf8(
      password.padRight(32, '0').substring(0, 32),
    );
    final iv = encrypt.IV.fromUtf8(
      "1234567890123456",
    ); // must match RegisterPage
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );

    final decrypted = encrypter.decrypt64(encryptedKey, iv: iv);

    print("🔓 Decrypted private key: $decrypted");
    return decrypted;
  }

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // ✅ Firebase login
      final userCred = await authService.value.signIn(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // ✅ Get wallet info from Firestore
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(userCred.user!.uid)
          .get();

      if (!doc.exists) {
        throw Exception("User data not found in Firestore");
      }

      final walletAddress = doc["walletAddress"];
      final encryptedKey = doc["privateKeyEnc"];

      final privateKey = _decryptPrivateKey(
        encryptedKey,
        passwordController.text.trim(),
      );

      final credentials = EthPrivateKey.fromHex(privateKey);
      final restoredAddr = credentials.address.hex;

      print("➡ Login success for: ${userCred.user!.email}");
      print("Wallet restored: $restoredAddr");
      print("Firestore wallet: $walletAddress");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Welcome back! Wallet: $restoredAddr")),
      );

      // 👉 Now redirect to home/dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login failed: $errorMessage")));
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
                  "Login",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),

                // Email
                TextFormField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Email"),
                  validator: (value) => value == null || value.isEmpty
                      ? "Please enter email"
                      : null,
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Password"),
                  validator: (value) => value == null || value.isEmpty
                      ? "Please enter password"
                      : null,
                ),

                const Spacer(),

                // Login button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text("Login", style: TextStyle(fontSize: 16)),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
