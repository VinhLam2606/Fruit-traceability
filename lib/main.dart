import 'package:flutter/material.dart';

import 'dashboard/ui/create_product_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/register',
      routes: {
        // '/register': (context) => const RegisterPage(),
        '/createProduct': (context) => const CreateProductPage(),
        // Later you can add '/login': (context) => const LoginPage(),
      },
    );
  }
}
