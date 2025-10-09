import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/dashboard/bloc/account_bloc.dart';
import 'package:untitled/dashboard/bloc/dashboard_bloc.dart';
import 'package:untitled/dashboard/bloc/organization_bloc.dart';
import 'package:untitled/dashboard/bloc/scan_bloc.dart';
import 'package:untitled/dashboard/ui/account_page.dart';
import 'package:untitled/dashboard/ui/home_page.dart';
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
                ),
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
    final List<Widget> widgetOptions = [
      const HomePage(),
      const OrganizationManagementPage(),
      const ScanBarcodePage(),
      const ProductManagementPage(),
      const AccountPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: widgetOptions),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Organization',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
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
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}