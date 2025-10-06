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
                      // 🔹 Load lại dữ liệu (nếu cần)
                      context.read<OrganizationBloc>().add(
                        FetchOrganizationDetails(),
                      );
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

          // 🔹 Nếu có lỗi trong lần đầu load (chưa có org nào)
          if (state is OrganizationError &&
              state is! OrganizationActionSuccess) {
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
                  showDialog(
                    context: dialogContext,
                    builder: (_) => AlertDialog(
                      title: const Text("Invalid Email"),
                      content: const Text(
                        "Please enter a valid email address.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text("OK"),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                context.read<OrganizationBloc>().add(AddMemberByEmail(email));
                Navigator.pop(dialogContext);
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }
}
