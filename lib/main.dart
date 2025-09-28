// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'dashboard/bloc/dashboard_bloc.dart';
import 'dashboard/ui/create_product_page.dart';
import 'auth/ui/register_page.dart';
import 'auth/ui/welcome_page.dart';
import 'auth/ui/home_page.dart';
import 'auth/ui/login_page.dart'; // 👈 you created this
import 'auth/auth_layout.dart'; // 👈 AuthLayout, WelcomePage, etc.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<DashboardBloc>(
          create: (_) => DashboardBloc()..add(DashboardInitialFetchEvent()),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const AuthLayout(), // 👈 Root is AuthLayout
        routes: {
          "/welcome": (context) => const WelcomePage(),
          "/register": (_) => const RegisterPage(),
          "/login": (_) => const LoginPage(),
          "/home": (_) => const HomePage(),
          "/createProduct": (_) => const CreateProductPage(),
        },
      ),
    );
  }
}
