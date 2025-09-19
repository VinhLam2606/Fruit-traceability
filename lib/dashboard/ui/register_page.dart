import 'package:flutter/material.dart';
import '../model/register.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _role = "user"; // default role
  bool _loading = false;

  final RegisterService _registerService = RegisterService();

  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      final result = await _registerService.registerUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        role: _role,
      );

      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    } catch (e) {
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _role,
              items: const [
                DropdownMenuItem(value: "user", child: Text("User Account")),
                DropdownMenuItem(
                  value: "organization",
                  child: Text("Organization Account"),
                ),
              ],
              onChanged: (val) {
                setState(() => _role = val!);
              },
              decoration: const InputDecoration(labelText: "Account Type"),
            ),
            const SizedBox(height: 30),
            _loading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _register,
                      child: const Text("Register"),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
