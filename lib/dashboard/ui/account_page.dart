// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/auth/service/auth_service.dart'; // ✅ 1. Thêm import
import 'package:untitled/dashboard/bloc/account_bloc.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AccountBloc()..add(FetchAccountDetails()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Account'),
          // ✅ 2. Thêm nút đăng xuất vào đây
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: "Sign out",
              onPressed: () async {
                await authService.value.signOut();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✅ Signed out successfully")),
                );
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
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    _buildInfoCard('User Name', state.userName),
                    _buildInfoCard('Role', state.role),
                    _buildInfoCard(
                      'Wallet Address',
                      state.userAddress,
                      isAddress: true,
                    ),
                  ],
                ),
              );
            }
            if (state is AccountError) {
              return Center(child: Text(state.error));
            }
            return const Center(child: Text("Press button to load data."));
          },
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, {bool isAddress = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: isAddress ? 12 : 16,
            color: Colors.black87,
          ),
        ),
        trailing: isAddress ? const Icon(Icons.copy) : null,
        onTap: isAddress
            ? () {
                // Logic sao chép địa chỉ (sẽ thêm sau)
              }
            : null,
      ),
    );
  }
}
