// main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth/auth_layout.dart';
import 'auth/ui/home_page.dart';
import 'auth/ui/login_page.dart';
import 'auth/ui/register_page.dart';
import 'dashboard/ui/create_product_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ❌ KHÔNG dùng MultiBlocProvider hay BlocProvider ở đây.
    // Việc này sẽ do AuthLayout xử lý sau khi đăng nhập thành công.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const AuthLayout(), // Widget gốc là AuthLayout
      routes: {
        "/register": (_) => const RegisterPage(),
        "/login": (_) => const LoginPage(),
        "/home": (_) => const HomePage(),
        "/createProduct": (_) => const CreateProductPage(),
      },
    );
  }
}
