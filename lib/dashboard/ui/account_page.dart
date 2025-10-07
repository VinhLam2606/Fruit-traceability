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
    context.read<AccountBloc>().add(FetchAccountDetails());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Tài Khoản',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: "Đăng xuất",
            onPressed: () async {
              await authService.value.signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✅ Đã đăng xuất thành công")),
                );
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthLayout()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF141E30), Color(0xFF243B55)],
          ),
        ),
        child: BlocBuilder<AccountBloc, AccountState>(
          builder: (context, state) {
            if (state is AccountLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.greenAccent),
              );
            }

            if (state is AccountLoaded) {
              return RefreshIndicator(
                color: Colors.greenAccent,
                onRefresh: () async {
                  context.read<AccountBloc>().add(FetchAccountDetails());
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 100,
                  ),
                  children: [
                    // 🌟 Profile header card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.greenAccent.withOpacity(0.6),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.greenAccent,
                            child: Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            state.userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.greenAccent.withOpacity(0.6),
                              ),
                            ),
                            child: Text(
                              state.role,
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 35),

                    // ⚡ Wallet section
                    const Text(
                      "Thông tin tài khoản",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildInfoCard(
                      'Địa chỉ ví',
                      state.userAddress,
                      isAddress: true,
                      context: context,
                    ),
                    const SizedBox(height: 10),
                    _buildInfoCard('Tên người dùng', state.userName),
                    _buildInfoCard('Vai trò', state.role),

                    const SizedBox(height: 60),
                    Center(
                      child: Text(
                        "Blockchain Connected Wallet",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Icon(
                        Icons.link_rounded,
                        size: 40,
                        color: Colors.greenAccent.withOpacity(0.7),
                      ),
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
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }

            return const Center(
              child: Text(
                "Đang tải dữ liệu...",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value, {
    bool isAddress = false,
    BuildContext? context,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: isAddress ? 13 : 16,
            color: Colors.white,
            fontFamily: isAddress ? "monospace" : null,
          ),
        ),
        trailing: isAddress
            ? IconButton(
                icon: const Icon(
                  Icons.copy,
                  color: Colors.greenAccent,
                  size: 20,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context!).showSnackBar(
                    const SnackBar(content: Text('📋 Đã sao chép địa chỉ ví!')),
                  );
                },
              )
            : null,
      ),
    );
  }
}
