import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart';
import 'package:untitled/dashboard/bloc/user_organization_bloc.dart';
import 'package:web3dart/web3dart.dart';

import '../../../auth/service/auth_service.dart';

class OrgUserPage extends StatelessWidget {
  const OrgUserPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = authService.value;

    // ✅ Kiểm tra trạng thái đăng nhập
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

    // ✅ Tạo web3 client & credentials
    final rpcUrl = "http://10.0.2.2:7545";
    final client = Web3Client(rpcUrl, Client());
    final creds = EthPrivateKey.fromHex(service.decryptedPrivateKey!);

    return BlocProvider(
      create: (_) =>
          UserOrganizationBloc(web3client: client, credentials: creds)
            ..add(FetchUserOrganization()),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("My Organization"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
          centerTitle: true,
        ),
        body: BlocBuilder<UserOrganizationBloc, UserOrganizationState>(
          builder: (context, state) {
            if (state is UserOrganizationLoading) {
              return const Center(child: CircularProgressIndicator());
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
    );
  }

  // 🔹 Không có tổ chức
  Widget _buildNoOrganizationView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 80),
            SizedBox(height: 24),
            Text(
              "You are not part of any organization.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87, fontSize: 18),
            ),
            SizedBox(height: 16),
            Text(
              "Contact your manufacturer or organization admin to be added.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 14),
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
      onRefresh: () async {
        context.read<UserOrganizationBloc>().add(FetchUserOrganization());
      },
      child: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          const Icon(Icons.apartment, color: Colors.blueAccent, size: 80),
          const SizedBox(height: 16),
          Text(
            org.organizationName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Owner: ${org.ownerName}",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 16),
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.black12),
          const SizedBox(height: 16),
          Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.blueGrey),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "You are currently a member of this organization.",
                  style: TextStyle(color: Colors.black87, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
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
                    context.read<UserOrganizationBloc>().add(
                      FetchUserOrganization(),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text("Reload Organization Info"),
                ),
                if (!isOwner) ...[
                  const SizedBox(height: 16),
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
                          title: const Text("Leave Organization?"),
                          content: const Text(
                            "Are you sure you want to leave this organization? You’ll lose your member status.",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);

                                // ✅ Dùng context gốc, không dùng dialogContext
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
