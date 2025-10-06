// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/auth/service/auth_service.dart';
import 'package:untitled/dashboard/bloc/account_bloc.dart';

import '../../auth/auth_layout.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  @override
  void initState() {
    super.initState();
    // ✅ Tải dữ liệu ngay khi trang được tạo
    context.read<AccountBloc>().add(FetchAccountDetails());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài Khoản'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Đăng xuất",
            onPressed: () async {
              await authService.value.signOut();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✅ Đã đăng xuất thành công")),
                );

                // 👉 Quay lại màn hình gốc (AuthLayout)
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthLayout()),
                  (route) => false, // Xóa toàn bộ history
                );
              }
            },
          ),
        ],
      ),
      body: BlocBuilder<AccountBloc, AccountState>(
        builder: (context, state) {
          if (state is AccountLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AccountLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<AccountBloc>().add(FetchAccountDetails());
              },
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildInfoCard('Tên Người Dùng', state.userName),
                  _buildInfoCard('Vai Trò', state.role),
                  _buildInfoCard(
                    'Địa Chỉ Ví',
                    state.userAddress,
                    isAddress: true,
                    context: context,
                  ),
                ],
              ),
            );
          }
          if (state is AccountError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  state.error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          return const Center(child: Text("Đang tải dữ liệu..."));
        },
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value, {
    bool isAddress = false,
    BuildContext? context,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: isAddress ? 13 : 16,
            color: Colors.black87,
          ),
        ),
        trailing: isAddress ? const Icon(Icons.copy, size: 20) : null,
        onTap: isAddress
            ? () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context!).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép địa chỉ ví!')),
                );
              }
            : null,
      ),
    );
  }
}
