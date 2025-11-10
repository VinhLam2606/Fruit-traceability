import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/dashboard/bloc/account_bloc.dart';
import 'package:untitled/dashboard/bloc/dashboard_bloc.dart';
import 'package:untitled/dashboard/bloc/organization_bloc.dart';
import 'package:untitled/dashboard/bloc/scan_bloc.dart';
import 'package:untitled/dashboard/bloc/user_organization_bloc.dart';
import 'package:untitled/dashboard/ui/account_page.dart';
import 'package:untitled/dashboard/ui/organization_management_page.dart';
import 'package:untitled/dashboard/ui/scan_barcode_page.dart';

import '../dashboard/ui/product_management.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      // ✅✅✅ SỬA LỖI QUAN TRỌNG NHẤT ✅✅✅
      // `buildWhen` ngăn BlocBuilder phá huỷ UI chính
      // khi có các state loading/error (do tạo/transfer sản phẩm)
      buildWhen: (previous, current) {
        // Nếu state trước đó là một state thành công (đã vào app)
        if (previous is DashboardInitialSuccessState ||
            previous is ProductsLoadedState ||
            previous is DashboardSuccessState) {
          // Và state mới là loading/error (do tạo sản phẩm, etc.)
          if (current is DashboardLoadingState ||
              current is DashboardErrorState) {
            // Thì KHÔNG xây dựng lại -> UI chính được giữ nguyên
            return false;
          }
        }
        // Cho phép xây dựng lại trong mọi trường hợp khác (như lúc khởi động)
        return true;
      },
      builder: (context, state) {
        // 1. Xử lý lúc khởi động
        if (state is DashboardLoadingState || state is DashboardInitial) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. Xử lý lỗi khởi động
        if (state is DashboardErrorState) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Lỗi Khởi Tạo:\n${state.error}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        // Thêm nút thử lại
                        context.read<DashboardBloc>().add(
                          DashboardInitialFetchEvent(),
                        );
                      },
                      child: const Text("Thử lại"),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // 3. Xây dựng UI chính (chỉ chạy 1 lần lúc khởi động thành công)
        // Nhờ `buildWhen`, nó sẽ không chạy lại và phá huỷ UI
        // khi `state` là `DashboardLoadingState` (do tạo sản phẩm)
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

        // 4. Trạng thái dự phòng
        return const Scaffold(
          body: Center(child: Text("Trạng thái không xác định.")),
        );
      },
    );
  }

  Widget _buildScaffold() {
    final List<Widget> widgetOptions = [
      const ScanBarcodePage(), // Index 0: Scan
      const OrganizationManagementPage(), // Index 1: Organization
      const ProductManagementPage(), // Index 2: Product
      const AccountPage(), // Index 3: Account
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF141E30), Color(0xFF243B55)],
          ),
        ),
        child: IndexedStack(index: _selectedIndex, children: widgetOptions),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Organization',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Product',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Account',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.greenAccent,
        unselectedItemColor: Colors.white70,
        backgroundColor: const Color(0xFF243B55),
        showUnselectedLabels: true,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
