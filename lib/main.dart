import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // ✅ added
import 'auth/bloc/auth_bloc.dart'; // ✅ added
import 'auth/service/auth_service.dart'; // ✅ added

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
    // ✅ Provide AuthBloc here so Login/Register can access it
    return BlocProvider(
      create: (_) => AuthBloc(authService.value),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const AuthLayout(),
        routes: {
          "/register": (_) => const RegisterPage(),
          "/login": (_) => const LoginPage(),
          "/home": (_) => const HomePage(),
          "/createProduct": (_) => const CreateProductPage(),
        },
      ),
    );
  }
}
