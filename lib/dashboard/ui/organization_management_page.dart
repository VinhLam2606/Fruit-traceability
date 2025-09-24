import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/dashboard/bloc/organization_bloc.dart';
import 'package:untitled/dashboard/model/product.dart';
import 'package:untitled/dashboard/model/user.dart';

class OrganizationManagementPage extends StatelessWidget {
  const OrganizationManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Sử dụng BlocProvider để cung cấp OrganizationBloc cho cây widget
    return BlocProvider(
      create: (context) => OrganizationBloc()..add(FetchOrganizationDetails()),
      child: Scaffold(
        appBar: AppBar(title: const Text("Organization Management")),
        body: BlocConsumer<OrganizationBloc, OrganizationState>(
          // Lắng nghe các state thay đổi để hiển thị SnackBar (thành công/lỗi)
          listener: (context, state) {
            if (state is OrganizationActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
              // Tải lại dữ liệu sau khi thực hiện hành động thành công
              context.read<OrganizationBloc>().add(FetchOrganizationDetails());
            } else if (state is OrganizationError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          // Xây dựng UI dựa trên state hiện tại của BLoC
          builder: (context, state) {
            if (state is OrganizationLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is OrganizationLoaded) {
              return _buildLoadedView(context, state);
            }
            if (state is OrganizationError) {
              return Center(child: Text(state.error));
            }
            return const Center(child: Text("Initializing..."));
          },
        ),
      ),
    );
  }

  // Widget chính hiển thị toàn bộ thông tin khi đã tải xong
  Widget _buildLoadedView(BuildContext context, OrganizationLoaded state) {
    return RefreshIndicator(
      onRefresh: () async {
        // Cho phép kéo để làm mới dữ liệu
        context.read<OrganizationBloc>().add(FetchOrganizationDetails());
      },
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. Phần thông tin tổ chức
          Text(
            state.organization.organizationName,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text("Owner: ${state.organization.ownerName}"),
          const SizedBox(height: 20),

          // 2. Phần quản lý thành viên (đã được cập nhật)
          _buildMembersSection(
            context,
            state.organization.members,
            state.organization.ownerAddress,
          ),
          const SizedBox(height: 20),

          // 3. Phần danh sách sản phẩm
          _buildProductsSection(context, state.products),
        ],
      ),
    );
  }

  // Widget hiển thị danh sách thành viên và các nút hành động
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
            // Nút "+" để gọi dialog thêm thành viên
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green, size: 30),
              onPressed: () => _showAddMemberDialog(context),
            ),
          ],
        ),
        const Divider(),
        // Hiển thị danh sách thành viên hoặc thông báo nếu rỗng
        members.isEmpty
            ? const Text("No members found.")
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  // Chủ sở hữu không thể bị xóa
                  final isOwner =
                      member.userId.toLowerCase() == ownerAddress.toLowerCase();
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(member.userName),
                    subtitle: Text(
                      member.userId,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    // Chỉ hiển thị nút xóa cho các thành viên không phải là chủ sở hữu
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
                              // Gửi sự kiện xóa thành viên tới BLoC
                              // BLoC sẽ gọi hàm `removeAssociateFromOrganization` trong smart contract
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

  // Dialog để nhập địa chỉ ví của thành viên mới
  void _showAddMemberDialog(BuildContext context) {
    final TextEditingController addressController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Add New Member"),
          content: TextField(
            controller: addressController,
            decoration: const InputDecoration(
              labelText: "Member's Wallet Address",
              hintText: "0x...",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final address = addressController.text.trim();
                if (address.isNotEmpty) {
                  // Gửi sự kiện thêm thành viên tới BLoC
                  // BLoC sẽ gọi hàm `addAssociateToOrganization` trong smart contract
                  context.read<OrganizationBloc>().add(
                    AddMemberToOrganization(address),
                  );
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  // Widget hiển thị danh sách sản phẩm (không thay đổi)
  Widget _buildProductsSection(BuildContext context, List<Product> products) {
    // ... giữ nguyên code của bạn ...
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Products (${products.length})",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Divider(),
        if (products.isEmpty)
          const Text("No products created by this organization."),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return Card(
              child: ListTile(
                title: Text(product.name),
                subtitle: Text("Batch ID: ${product.batchId}"),
              ),
            );
          },
        ),
      ],
    );
  }
}
