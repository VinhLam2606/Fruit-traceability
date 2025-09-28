// auth_layout.dart
import 'package:flutter/material.dart';
import 'service/auth_service.dart';
import 'ui/home_page.dart';
import 'ui/welcome_page.dart';

class AppLoadingPage extends StatelessWidget {
  const AppLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class AppNavigationLayout extends StatelessWidget {
  const AppNavigationLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fruit Traceability Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.value.signOut();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("✅ Signed out successfully")),
              );
            },
          ),
        ],
      ),
      body: const HomePage(), // ✅ show your real homepage
    );
  }
}

class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, this.pageIfNotConnected});

  final Widget? pageIfNotConnected;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream:
          authService.value.authStateChanges, // ✅ listen directly to Firebase
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingPage();
        } else if (snapshot.hasData) {
          return const AppNavigationLayout(); // logged in
        } else {
          return pageIfNotConnected ?? const WelcomePage(); // logged out
        }
      },
    );
  }
}
