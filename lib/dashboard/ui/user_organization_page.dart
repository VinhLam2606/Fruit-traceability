import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart';
import 'package:untitled/dashboard/bloc/user_organization_bloc.dart';
import 'package:web3dart/web3dart.dart';

import '../../../auth/service/auth_service.dart';

class OrgUserPage extends StatelessWidget {
  const OrgUserPage({super.key});

  // --- Style constants ---
  static const List<Color> _backgroundGradient = [
    Color(0xFF141E30), // Darker
    Color(0xFF243B55), // Slightly Lighter
  ];
  static const Color _accentColor = Colors.greenAccent;
  static const Color _cardColor = Colors.white10;

  @override
  Widget build(BuildContext context) {
    final service = authService.value;

    // Kiểm tra trạng thái đăng nhập
    if (service.currentUser == null ||
        service.decryptedPrivateKey == null ||
        service.walletAddress == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            "Please log in again to view your organization.",
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ),
      );
    }

    // Tạo web3 client & credentials
    final rpcUrl = "http://192.168.102.5:7545";
    final client = Web3Client(rpcUrl, Client());
    final creds = EthPrivateKey.fromHex(service.decryptedPrivateKey!);

    return BlocProvider(
      create: (_) =>
          UserOrganizationBloc(web3client: client, credentials: creds)
            ..add(FetchUserOrganization()),
      // ✅ Áp dụng Container gradient cho toàn bộ trang
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _backgroundGradient,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent, // Cần thiết
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              "My Organization",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: BlocBuilder<UserOrganizationBloc, UserOrganizationState>(
            builder: (context, state) {
              if (state is UserOrganizationLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: _accentColor),
                );
              }

              if (state is UserOrganizationEmpty) {
                return _buildNoOrganizationView();
              }

              if (state is UserOrganizationLoaded) {
                final org = state.organization;
                return _buildOrganizationInfo(context, org, creds);
              }

              if (state is UserOrganizationError) {
                return Center(
                  child: Text(
                    state.message,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  // --- UI Sections ---

  // 🔹 Không có tổ chức
  Widget _buildNoOrganizationView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.amberAccent,
              size: 80,
            ),
            SizedBox(height: 24),
            Text(
              "You are not part of any organization.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            Text(
              "Contact your manufacturer or organization admin to be added.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Hiển thị thông tin tổ chức
  Widget _buildOrganizationInfo(
    BuildContext context,
    org,
    EthPrivateKey creds,
  ) {
    final isOwner =
        org.ownerAddress.toLowerCase() == creds.address.hex.toLowerCase();

    return RefreshIndicator(
      color: _accentColor,
      onRefresh: () async {
        context.read<UserOrganizationBloc>().add(FetchUserOrganization());
      },
      child: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // Header Icon
          Icon(Icons.apartment, color: _accentColor, size: 80),
          const SizedBox(height: 16),

          // Organization Name
          Text(
            org.organizationName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Owner Info
          Text(
            "Owner: ${org.ownerName}",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),

          // Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user, color: _accentColor, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOwner ? "Organization Owner" : "Organization Member",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "Your role within this organization is established on the blockchain.",
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Center(
            child: Column(
              children: [
                // Reload Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white12, // Màu nền tối
                    foregroundColor: Colors.white, // Màu chữ/icon
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.white30),
                    ),
                  ),
                  onPressed: () {
                    context.read<UserOrganizationBloc>().add(
                      FetchUserOrganization(),
                    );
                  },
                  icon: const Icon(Icons.refresh, color: _accentColor),
                  label: const Text("Reload Organization Info"),
                ),
                if (!isOwner) ...[
                  const SizedBox(height: 16),
                  // Leave Organization Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          backgroundColor: const Color(0xFF243B55),
                          title: const Text(
                            "Leave Organization?",
                            style: TextStyle(color: Colors.white),
                          ),
                          content: const Text(
                            "Are you sure you want to leave this organization? You’ll lose your member status.",
                            style: TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            // ✅ Nút 1 (Bên trái): CANCEL
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(color: _accentColor),
                              ),
                            ),
                            // ✅ Nút 2 (Bên phải): CONFIRM LEAVE (Hành động nguy hiểm)
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);

                                // Dùng context gốc, không dùng dialogContext
                                context.read<UserOrganizationBloc>().add(
                                  LeaveOrganization(),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                              ),
                              child: const Text("Confirm Leave"),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text("Leave Organization"),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
