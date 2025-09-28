// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:untitled/auth/service/auth_service.dart';

class LoginPage extends StatefulWidget {
  final Function()? onTap; // Add this for toggling
  const LoginPage({super.key, this.onTap});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String errorMessage = '';
  bool _isLoading = false;

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
    ); // Must match the IV in RegisterPage
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );

    final decrypted = encrypter.decrypt64(encryptedKey, iv: iv);
    print("🔓 Decrypted private key successfully");
    return decrypted;
  }

  Future<void> login() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      // ✅ Firebase login
      final userCred = await authService.value.signIn(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // ✅ Get wallet info from Firestore to verify decryption
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(userCred.user!.uid)
          .get();

      if (!doc.exists) {
        throw Exception("User data not found in Firestore.");
      }

      final encryptedKey = doc["privateKeyEnc"];

      // This step implicitly verifies the password is correct.
      // If it's wrong, this will throw an exception.
      _decryptPrivateKey(encryptedKey, passwordController.text.trim());

      print("➡ Login success for: ${userCred.user!.email}");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("✅ Welcome back!")));

      // No need to navigate here. The AuthLayout will detect the
      // auth state change and automatically navigate to the dashboard.
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Login failed: Invalid email or password.")),
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
                    "Welcome Back",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Login to continue",
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 40),

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
                  const SizedBox(height: 30),

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
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text("Login", style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Toggle to Register Page
                  RichText(
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style: const TextStyle(color: Colors.white54),
                      children: [
                        TextSpan(
                          text: "Register now",
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
