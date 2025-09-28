// lib/dashboard/ui/home_page.dart
import 'package:flutter/material.dart';
import 'package:untitled/auth/service/auth_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🍏 Fruit Traceability"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Sign out",
            onPressed: () async {
              await authService.value.signOut();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("✅ Signed out successfully")),
              );
            },
          ),
        ],
      ),
      body: const Center(
        child: Text(
          "Welcome to Fruit Traceability Blockchain App!",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
