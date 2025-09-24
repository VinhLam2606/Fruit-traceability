import 'package:flutter/material.dart';
import 'package:untitled/navigation/main_navigation.dart'; // Thay đổi import

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Traceability DApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // THAY ĐỔI: Khởi chạy trang điều hướng chính
      home: const MainNavigationPage(),
    );
  }
}
