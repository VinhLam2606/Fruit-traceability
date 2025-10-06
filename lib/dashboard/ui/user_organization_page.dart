// lib/dashboard/ui/user_organization_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:untitled/auth/service/auth_service.dart';

class OrgUserPage extends StatefulWidget {
  const OrgUserPage({super.key});

  @override
  State<OrgUserPage> createState() => _OrgUserPageState();
}

class _OrgUserPageState extends State<OrgUserPage> {
  String? organizationName;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrganization();
  }

  Future<void> _loadOrganization() async {
    final user = authService.value.currentUser;
    if (user == null) {
      setState(() {
        organizationName = null;
        isLoading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        organizationName = doc.data()!['organization'] as String?;
      }
    } catch (e) {
      debugPrint("❌ [OrgUserPage] Error loading organization: $e");
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.greenAccent),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("My Organization"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.greenAccent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                organizationName != null
                    ? Icons.apartment
                    : Icons.warning_amber_rounded,
                color: Colors.greenAccent,
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                organizationName != null
                    ? "You are part of:\n$organizationName"
                    : "You are not part of any organization.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 16),
              if (organizationName == null)
                const Text(
                  "Contact your manufacturer or organization admin to be added.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
