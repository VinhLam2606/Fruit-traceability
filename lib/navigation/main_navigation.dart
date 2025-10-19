import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/dashboard/bloc/account_bloc.dart';
import 'package:untitled/dashboard/bloc/dashboard_bloc.dart';
import 'package:untitled/dashboard/bloc/organization_bloc.dart';
import 'package:untitled/dashboard/bloc/scan_bloc.dart';
import 'package:untitled/dashboard/bloc/user_organization_bloc.dart';
import 'package:untitled/dashboard/ui/account_page.dart';
// import 'package:untitled/dashboard/ui/home_page.dart'; // Đã xóa import HomePage
import 'package:untitled/dashboard/ui/organization_management_page.dart';
import 'package:untitled/dashboard/ui/scan_barcode_page.dart';

import '../dashboard/ui/product_management.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  // ✅ Sau khi xóa Home, chỉ còn 4 trang. Index bắt đầu từ 0.
  // Trang ScanBarCodePage sẽ là index 0.
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoadingState || state is DashboardInitial) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is DashboardErrorState) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Lỗi Khởi Tạo:\n${state.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        if (state is DashboardInitialSuccessState ||
            state is ProductsLoadedState ||
            state is DashboardSuccessState) {
          final dashboardBloc = context.read<DashboardBloc>();

          return MultiBlocProvider(
            providers: [
              BlocProvider<AccountBloc>(
                create: (context) => AccountBloc(
                  web3client: dashboardBloc.web3client,
                  deployedContract: dashboardBloc.deployedContract,
                ),
              ),
              BlocProvider<OrganizationBloc>(
                create: (context) => OrganizationBloc(
                  web3client: dashboardBloc.web3client,
                  credentials: dashboardBloc.credentials,
                )..add(FetchOrganizationDetails()),
              ),
              // ScanBloc giờ chỉ cần web3client
              BlocProvider<ScanBloc>(
                create: (context) => ScanBloc(
                  web3client: dashboardBloc.web3client,
                  credentials: dashboardBloc.credentials,
                ),
              ),
              BlocProvider<UserOrganizationBloc>(
                create: (context) => UserOrganizationBloc(
                  web3client: dashboardBloc.web3client,
                  credentials: dashboardBloc.credentials,
                )..add(FetchUserOrganization()),
              ),
            ],
            child: _buildScaffold(),
          );
        }

        return const Scaffold(
          body: Center(child: Text("Trạng thái không xác định.")),
        );
      },
    );
  }

  Widget _buildScaffold() {
    // ✅ XÓA HomePage VÀ DỜI ScanBarcodePage LÊN ĐẦU TIÊN
    final List<Widget> widgetOptions = [
      const ScanBarcodePage(), // Index 0: Scan
      const OrganizationManagementPage(), // Index 1: Organization
      const ProductManagementPage(), // Index 2: Product
      const AccountPage(), // Index 3: Account
    ];

    return Scaffold(
      // Áp dụng màu nền gradient tối cho toàn bộ màn hình
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF141E30), Color(0xFF243B55)],
          ),
        ),
        // Sử dụng IndexedStack để giữ trạng thái của các trang con
        child: IndexedStack(index: _selectedIndex, children: widgetOptions),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          // ✅ DỜI SCAN LÊN ĐẦU (Index 0)
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          // ✅ DỜI ORGANIZATION LÊN VỊ TRÍ THỨ 2 (Index 1)
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Organization',
          ),
          // ✅ PRODUCT (Index 2)
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Product',
          ),
          // ✅ ACCOUNT (Index 3)
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Account',
          ),
        ],
        currentIndex: _selectedIndex,
        // Cập nhật màu sắc cho BottomNavigationBar
        selectedItemColor: Colors.greenAccent, // Màu điểm nhấn
        unselectedItemColor: Colors.white70, // Màu cho item không được chọn
        backgroundColor: const Color(0xFF243B55), // Màu nền tối
        showUnselectedLabels: true,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
