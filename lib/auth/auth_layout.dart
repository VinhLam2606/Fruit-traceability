// lib/auth/auth_layout.dart

import 'package:flutter/material.dart';
// ✅ Thêm import cho trang điều hướng chính của bạn
import 'package:untitled/navigation/main_navigation.dart';

import 'service/auth_service.dart';
import 'ui/login_or_register_page.dart';

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
    // 🚀 THAY ĐỔI CHÍNH
    // Trả về MainNavigationPage thay vì HomePage hoặc một Scaffold tùy chỉnh.
    // MainNavigationPage đã chứa tất cả logic bạn cần cho màn hình chính.
    return const MainNavigationPage();
  }
}

class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: authService.value.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingPage();
        } else if (snapshot.hasData) {
          // Người dùng đã đăng nhập, hiển thị AppNavigationLayout
          return const AppNavigationLayout();
        } else {
          // Người dùng chưa đăng nhập, hiển thị trang đăng nhập/đăng ký
          return const LoginOrRegisterPage();
        }
      },
    );
  }
}
