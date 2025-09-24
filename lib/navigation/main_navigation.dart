// dashboard/ui/main_navigation.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/dashboard/bloc/dashboard_bloc.dart';
import 'package:untitled/dashboard/bloc/organization_bloc.dart';
import 'package:untitled/dashboard/ui/account_page.dart';
import 'package:untitled/dashboard/ui/create_product_page.dart';
import 'package:untitled/dashboard/ui/home_page.dart';
import 'package:untitled/dashboard/ui/organization_management_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;
  late List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    final dashboardBloc = context.read<DashboardBloc>();

    _widgetOptions = <Widget>[
      const HomePage(),
      BlocProvider<OrganizationBloc>(
        create: (context) => OrganizationBloc(
          web3client: dashboardBloc.web3client,
          deployedContract: dashboardBloc.deployedContract,
          credentials: dashboardBloc.credentials,
        )..add(FetchOrganizationDetails()),
        child: const OrganizationManagementPage(),
      ),
      const CreateProductPage(),
      const AccountPage(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoadingState || state is DashboardInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is DashboardErrorState) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  // TRANSLATION: Changed the error message to English.
                  "Initialization Error: ${state.error}",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return IndexedStack(index: _selectedIndex, children: _widgetOptions);
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
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
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
