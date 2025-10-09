// lib/navigation/customer_navigation.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/dashboard/bloc/account_bloc.dart';
import 'package:untitled/dashboard/ui/account_page.dart';
import 'package:web3dart/web3dart.dart';

import '../dashboard/ui/scan_barcode_page.dart';
import '../dashboard/ui/user_organization_page.dart';

class CustomerNavigationPage extends StatefulWidget {
  final Web3Client web3client;
  final DeployedContract deployedContract;

  const CustomerNavigationPage({
    super.key,
    required this.web3client,
    required this.deployedContract,
  });

  @override
  State<CustomerNavigationPage> createState() => _CustomerNavigationPageState();
}

class _CustomerNavigationPageState extends State<CustomerNavigationPage> {
  int _currentIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AccountBloc(
        web3client: widget.web3client,
        deployedContract: widget.deployedContract,
      )..add(FetchAccountDetails()),
      child: _buildScaffold(),
    );
  }

  // ✅ CHỈNH SỬA TẠI ĐÂY
  Widget _buildScaffold() {
    final List<Widget> pages = [
      const ScanBarcodePage(),
      const OrgUserPage(),
      const AccountPage(),
    ];

    return Scaffold(
      // 1. Áp dụng màu nền gradient tối cho toàn bộ màn hình
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // Sử dụng màu nền đồng bộ với AccountPage
            colors: [Color(0xFF141E30), Color(0xFF243B55)],
          ),
        ),
        // Sử dụng IndexedStack để giữ trạng thái của các trang con
        child: IndexedStack(index: _currentIndex, children: pages),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        // 2. Cập nhật màu sắc cho BottomNavigationBar
        backgroundColor: const Color(0xFF243B55), // Màu nền tối
        selectedItemColor: Colors.greenAccent, // Màu điểm nhấn
        unselectedItemColor: Colors.white70, // Màu cho item không được chọn
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: "Scanner",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apartment),
            label: "Organization",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: "Account",
          ),
        ],
      ),
    );
  }
}
