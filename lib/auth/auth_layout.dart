// lib/auth/auth_layout.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:untitled/dashboard/bloc/dashboard_bloc.dart';
import 'package:untitled/navigation/main_navigation.dart';
import 'package:web3dart/web3dart.dart';

import 'service/auth_service.dart';
import 'ui/login_or_register_page.dart';

class AppLoadingPage extends StatelessWidget {
  const AppLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthService>(
      valueListenable: authService,
      builder: (context, service, _) {
        // --- 1. Nếu chưa đăng nhập ---
        if (service.currentUser == null) {
          return const LoginOrRegisterPage();
        }

        // --- 2. Nếu đã đăng nhập nhưng chưa có private key hoặc address ---
        if (service.decryptedPrivateKey == null ||
            service.walletAddress == null) {
          return const LoginOrRegisterPage();
        }

        // --- 3. Nếu đã đăng nhập và có private key ---
        final rpcUrl = "http://10.0.2.2:7545"; // Android emulator dùng 10.0.2.2
        final web3client = Web3Client(rpcUrl, http.Client());

        final credentials = EthPrivateKey.fromHex(service.decryptedPrivateKey!);

        // Khởi tạo DashboardBloc tại đây, truyền credentials vào
        return BlocProvider<DashboardBloc>(
          create: (_) =>
              DashboardBloc(web3client: web3client, credentials: credentials)
                ..add(DashboardInitialFetchEvent()),
          child: const MainNavigationPage(),
        );
      },
    );
  }
}
