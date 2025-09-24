// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/dashboard/bloc/dashboard_bloc.dart';
import 'package:untitled/navigation//main_navigation.dart'; // Sửa lại đường dẫn nếu cần

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supply Chain DApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      // **THAY ĐỔI QUAN TRỌNG Ở ĐÂY**
      // Cung cấp DashboardBloc cho toàn bộ ứng dụng, bao gồm cả MainNavigationPage
      home: BlocProvider(
        create: (context) => DashboardBloc()..add(DashboardInitialFetchEvent()),
        child: const MainNavigationPage(),
      ),
    );
  }
}
