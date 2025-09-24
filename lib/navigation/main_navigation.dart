import 'package:flutter/material.dart';
import 'package:untitled/dashboard/ui/account_page.dart';
import 'package:untitled/dashboard/ui/create_product_page.dart'; // Trang này sẽ là "Product"
import 'package:untitled/dashboard/ui/home_page.dart';
import 'package:untitled/dashboard/ui/organization_management_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;

  // Danh sách các trang con tương ứng với mỗi tab
  static const List<Widget> _widgetOptions = <Widget>[
    HomePage(), // Trang Home
    OrganizationManagementPage(), // Trang Org
    CreateProductPage(), // Trang Product
    AccountPage(), // Trang Account
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sử dụng IndexedStack để giữ trạng thái của các trang khi chuyển tab
      body: IndexedStack(index: _selectedIndex, children: _widgetOptions),
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
        selectedItemColor: Colors.amber[800],
        unselectedItemColor:
            Colors.grey, // Hiển thị label cho item không được chọn
        showUnselectedLabels: true, // ---
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Đảm bảo tất cả item đều hiển thị
      ),
    );
  }
}
