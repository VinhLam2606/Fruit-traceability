import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/dashboard/bloc/organization_bloc.dart';
import 'package:untitled/dashboard/model/user.dart';

class OrganizationManagementPage extends StatelessWidget {
  const OrganizationManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Organization Management")),
      body: BlocConsumer<OrganizationBloc, OrganizationState>(
        listener: (context, state) {
          if (state is OrganizationActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            // 🟢 SỬA LỖI REFRESH TẠI ĐÂY: Kích hoạt fetch ngay sau khi hành động thành công
            // Điều này buộc Bloc phải chạy lại _onFetchDetails và emit OrganizationLoaded mới
            context.read<OrganizationBloc>().add(FetchOrganizationDetails());
          }
          // ✅ Hiển thị dialog lỗi nhẹ, KHÔNG mất trang
          else if (state is OrganizationError) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("Error"),
                content: Text(state.error),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Tải lại dữ liệu chỉ trong trường hợp lỗi xảy ra khi trạng thái chưa được load
                      if (state is! OrganizationLoaded) {
                        context.read<OrganizationBloc>().add(
                          FetchOrganizationDetails(),
                        );
                      }
                    },
                    child: const Text("OK"),
                  ),
                ],
              ),
            );
          }
        },
        builder: (context, state) {
          // 🔹 Nếu đang loading
          if (state is OrganizationLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // 🔹 Nếu đã load được tổ chức
          if (state is OrganizationLoaded) {
            return _buildLoadedView(context, state);
          }

          // 🔹 Nếu có lỗi trong lần đầu load
          if (state is OrganizationError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.error, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      context.read<OrganizationBloc>().add(
                        FetchOrganizationDetails(),
                      );
                    },
                    child: const Text("Thử lại"),
                  ),
                ],
              ),
            );
          }

          return const Center(child: Text("Initializing..."));
        },
      ),
    );
  }

  Widget _buildLoadedView(BuildContext context, OrganizationLoaded state) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<OrganizationBloc>().add(FetchOrganizationDetails());
      },
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            state.organization.organizationName,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text("Owner: ${state.organization.ownerName}"),
          const SizedBox(height: 20),
          _buildMembersSection(
            context,
            state.organization.members,
            state.organization.ownerAddress,
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection(
    BuildContext context,
    List<User> members,
    String ownerAddress,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Members (${members.length})",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green, size: 30),
              onPressed: () => _showAddMemberDialog(context),
            ),
          ],
        ),
        const Divider(),
        members.isEmpty
            ? const Text("No members found.")
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  final isOwner =
                      member.userId.toLowerCase() == ownerAddress.toLowerCase();
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(member.userName),
                    subtitle: Text(
                      member.userId,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: isOwner
                        ? const Chip(
                            label: Text('Owner'),
                            backgroundColor: Colors.amber,
                          )
                        : IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              context.read<OrganizationBloc>().add(
                                RemoveMemberFromOrganization(member.userId),
                              );
                            },
                          ),
                  );
                },
              ),
      ],
    );
  }

  /// 🔹 Thêm thành viên chỉ bằng Email
  void _showAddMemberDialog(BuildContext context) {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Add New Member by Email"),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: "Member's Email",
              hintText: "example@email.com",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final email = emailController.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  // ⚠️ Hiển thị SnackBar lỗi
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please enter a valid email address."),
                      backgroundColor: Colors.red,
                    ),
                  );
                  // Đóng dialog để người dùng có thể thử lại
                  Navigator.pop(dialogContext);
                  return;
                }

                // Gửi sự kiện thêm thành viên
                context.read<OrganizationBloc>().add(AddMemberByEmail(email));
                Navigator.pop(dialogContext); // Đóng dialog
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }
}
