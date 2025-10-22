// ignore_for_file: unused_field

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/auth/auth_layout.dart';
import 'package:untitled/auth/bloc/auth_bloc.dart';
import 'package:untitled/auth/bloc/auth_event.dart';
import 'package:untitled/auth/bloc/auth_state.dart';
import 'package:web3dart/web3dart.dart';
import 'organization_form_page.dart';

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

  late Web3Client ethClient;
  DeployedContract? usersContract;

  static String providedPrivateKey = "";
  static String providedAddress = "";

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
                      child: BlocConsumer<AuthBloc, AuthState>(
                        listener: (context, state) {
                          if (state is AuthSuccess) {
                            // 🔹 Nếu là organization → vào OrganizationFormPage
                            if (state.accountType == "organization") {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "🏢 Please complete your organization info",
                                  ),
                                ),
                              );

                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OrganizationFormPage(
                                    ethAddress: AuthBloc.providedAddress,
                                    privateKey: AuthBloc.providedPrivateKey,
                                  ),
                                ),
                                (route) => false,
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("✅ Registration successful!"),
                                ),
                              );

                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AuthLayout(),
                                ),
                                (route) => false,
                              );
                            }
                          } else if (state is AuthFailure) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "❌ Registration failed: ${state.message}",
                                ),
                              ),
                            );
                          }
                        },

                        builder: (context, state) {
                          final isLoading = state is AuthLoading;

                          return ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    if (_formKey.currentState!.validate()) {
                                      context.read<AuthBloc>().add(
                                        AuthRegisterRequested(
                                          email: emailController.text.trim(),
                                          password: passwordController.text
                                              .trim(),
                                          username: usernameController.text
                                              .trim(),
                                          accountType: accountType,
                                        ),
                                      );
                                    }
                                  },
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
                            child: isLoading
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
                          );
                        },
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
