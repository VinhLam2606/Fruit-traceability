// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/dashboard/bloc/organization_bloc.dart';
import 'package:untitled/dashboard/model/user.dart';

class OrganizationManagementPage extends StatelessWidget {
  const OrganizationManagementPage({super.key});

  // --- Style constants ---
  static const List<Color> _backgroundGradient = [
    Color(0xFF141E30), // Darker
    Color(0xFF243B55), // Lighter
  ];
  static const Color _accentColor = Colors.greenAccent;
  static const Color _cardColor = Colors.white10;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Apply background gradient to the whole page
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _backgroundGradient,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Crucial for showing the gradient
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            "Organization Management", // Translated
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: BlocConsumer<OrganizationBloc, OrganizationState>(
          listener: (context, state) {
            if (state is OrganizationActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: _accentColor,
                ),
              );
              // Trigger a fetch right after a successful action
              context.read<OrganizationBloc>().add(FetchOrganizationDetails());
            }
            // ✅ Display error dialog
            else if (state is OrganizationError) {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF243B55),
                  title: const Text(
                    "Action Error", // Translated
                    style: TextStyle(color: _accentColor),
                  ),
                  content: Text(
                    state.error,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (state is! OrganizationLoaded) {
                          context.read<OrganizationBloc>().add(
                            FetchOrganizationDetails(),
                          );
                        }
                      },
                      child: const Text(
                        "OK",
                        style: TextStyle(color: _accentColor),
                      ),
                    ),
                  ],
                ),
              );
            }
          },
          builder: (context, state) {
            // 🔹 If loading
            if (state is OrganizationLoading) {
              return const Center(
                child: CircularProgressIndicator(color: _accentColor),
              );
            }

            // 🔹 If organization is loaded
            if (state is OrganizationLoaded) {
              return _buildLoadedView(context, state);
            }

            // 🔹 If there's an error on initial load
            if (state is OrganizationError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        "Error loading data:\n${state.error}", // Translated
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.read<OrganizationBloc>().add(
                          FetchOrganizationDetails(),
                        );
                      },
                      icon: const Icon(Icons.refresh, color: Colors.black),
                      label: const Text(
                        "Retry", // Translated
                        style: TextStyle(color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return const Center(
              child: Text(
                "Initializing...", // Translated
                style: TextStyle(color: Colors.white70),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadedView(BuildContext context, OrganizationLoaded state) {
    return RefreshIndicator(
      color: _accentColor,
      onRefresh: () async {
        context.read<OrganizationBloc>().add(FetchOrganizationDetails());
      },
      child: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: _accentColor.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.organization.organizationName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Owner: ${state.organization.ownerName}",
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                Text(
                  "Owner Address: ${state.organization.ownerAddress.substring(0, 10)}...",
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
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
            const Text(
              "Members", // Translated
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.person_add, color: _accentColor, size: 30),
              onPressed: () => _showAddMemberDialog(context),
            ),
          ],
        ),
        const Divider(color: Colors.white30),
        members.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 20.0),
                  child: Text(
                    "No members yet.", // Translated
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  final isOwner =
                      member.userId.toLowerCase() == ownerAddress.toLowerCase();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _accentColor.withOpacity(0.7),
                        child: Icon(
                          isOwner ? Icons.star : Icons.person,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                      // ✅ Ensure user NAME is displayed, otherwise show a placeholder
                      title: Text(
                        member.userName.isNotEmpty
                            ? member.userName
                            : "User (Name not set)", // Translated
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Display shortened wallet address as subtitle
                      subtitle: Text(
                        member.userId.substring(0, 10) + "...",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                      trailing: isOwner
                          ? const Chip(
                              label: Text('Owner'),
                              backgroundColor: Colors.amber,
                              labelStyle: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.person_remove,
                                color: Colors.redAccent,
                              ),
                              tooltip: "Remove Member",
                              onPressed: () {
                                context.read<OrganizationBloc>().add(
                                  RemoveMemberFromOrganization(member.userId),
                                );
                              },
                            ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  /// 🔹 Add member by Email only
  void _showAddMemberDialog(BuildContext context) {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF243B55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            "Add New Member", // Translated
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Member's Email", // Translated
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: "example@email.com",
              hintStyle: const TextStyle(color: Colors.white54),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: _accentColor),
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white30),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                "Cancel", // Translated
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final email = emailController.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "⚠️ Please enter a valid email address.",
                      ), // Translated
                      backgroundColor: Colors.red,
                    ),
                  );
                  Navigator.pop(dialogContext);
                  return;
                }

                context.read<OrganizationBloc>().add(AddMemberByEmail(email));
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text("Add"), // Translated
            ),
          ],
        );
      },
    );
  }
}
