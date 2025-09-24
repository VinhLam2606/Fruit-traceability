// dashboard/ui/organization_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/dashboard/bloc/organization_bloc.dart';
import 'package:untitled/dashboard/model/user.dart';

class OrganizationManagementPage extends StatelessWidget {
  const OrganizationManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // TRANSLATION: Changed AppBar title.
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
            context.read<OrganizationBloc>().add(FetchOrganizationDetails());
          } else if (state is OrganizationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error), backgroundColor: Colors.red),
            );
          }
        },
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
          // TRANSLATION: Changed initial text.
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
              // TRANSLATION: Changed section title.
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
            // TRANSLATION: Changed empty state text.
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

  void _showAddMemberDialog(BuildContext context) {
    final TextEditingController addressController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          // TRANSLATION: Changed dialog title.
          title: const Text("Add New Member"),
          content: TextField(
            controller: addressController,
            decoration: const InputDecoration(
              // TRANSLATION: Changed text field labels.
              labelText: "Member's Wallet Address",
              hintText: "0x...",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              // TRANSLATION: Changed button text.
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final address = addressController.text.trim();
                if (address.isNotEmpty) {
                  context.read<OrganizationBloc>().add(
                    AddMemberToOrganization(address),
                  );
                  Navigator.pop(dialogContext);
                }
              },
              // TRANSLATION: Changed button text.
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }
}
