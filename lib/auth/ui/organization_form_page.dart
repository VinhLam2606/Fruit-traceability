import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:untitled/auth/service/walletExt_service.dart';
import 'package:untitled/dashboard/bloc/dashboard_bloc.dart';
import 'package:untitled/navigation/main_navigation.dart';
import 'package:web3dart/web3dart.dart';

class OrganizationFormPage extends StatefulWidget {
  final String ethAddress;
  final String privateKey;

  const OrganizationFormPage({
    super.key,
    required this.ethAddress,
    required this.privateKey,
  });

  @override
  State<OrganizationFormPage> createState() => _OrganizationFormPageState();
}

class _OrganizationFormPageState extends State<OrganizationFormPage> {
  final _formKey = GlobalKey<FormState>();

  final fullNameController = TextEditingController();
  final brandController = TextEditingController();
  final businessTypeController = TextEditingController();
  final foundedYearController = TextEditingController();
  final addressController = TextEditingController();
  final emailController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    fullNameController.dispose();
    brandController.dispose();
    businessTypeController.dispose();
    foundedYearController.dispose();
    addressController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _saveOrganizationInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("No user logged in.");

      // 1️⃣ Save organization info to Firestore
      await FirebaseFirestore.instance
          .collection("organizations")
          .doc(uid)
          .set({
            "fullName": fullNameController.text.trim(),
            "brandName": brandController.text.trim(),
            "businessType": businessTypeController.text.trim(),
            "foundedYear": foundedYearController.text.trim(),
            "address": addressController.text.trim(),
            "email": emailController.text.trim(),
            "eth_address": widget.ethAddress,
            "private_key": widget.privateKey,
            "createdAt": FieldValue.serverTimestamp(),
          });

      // 2️⃣ Retrieve user’s private key from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();
      final privateKey = userDoc["private_key"] as String?;
      if (privateKey == null || privateKey.isEmpty) {
        throw Exception("Private key not found for this user!");
      }

      // 3️⃣ Init blockchain client
      await initContract();
      final credentials = EthPrivateKey.fromHex(privateKey);
      final walletAddress = await credentials.extractAddress();

      // 4️⃣ Check organization membership
      final fnCheck = usersContract!.function("getOrganization");
      final result = await ethClient.call(
        contract: usersContract!,
        function: fnCheck,
        params: [walletAddress],
      );
      final orgData = result.first as List<dynamic>;
      final orgName = orgData[0] as String;

      if (orgName.isNotEmpty) {
        print("🟡 Already has an organization on-chain, skipping creation.");
      } else {
        // 5️⃣ Register organization on-chain
        final txHash = await addOrganizationOnChain(
          fullNameController.text.trim(),
          credentials,
        );
        await waitForTxConfirmation(txHash);
        print("✅ Organization registered on blockchain: $txHash");
      }

      // 6️⃣ Success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Organization saved successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      // 7️⃣ Navigate directly into dashboard (same as post-login)
      final rpcUrl = "http://10.0.2.2:7545";
      final web3client = Web3Client(rpcUrl, http.Client());

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) =>
                DashboardBloc(web3client: web3client, credentials: credentials)
                  ..add(DashboardInitialFetchEvent()),
            child: const MainNavigationPage(),
          ),
        ),
        (route) => false, // clear navigation stack
      );
    } catch (e) {
      print("❌ Failed to save organization: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Failed to save organization: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Organization Information"),
        backgroundColor: Colors.greenAccent,
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF141E30), Color(0xFF243B55)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildField("Full Company Name", fullNameController),
              _buildField("Brand / Short Name", brandController),
              _buildField(
                "Business Type (LLC, JSC...)",
                businessTypeController,
              ),
              _buildField(
                "Founded Year",
                foundedYearController,
                keyboardType: TextInputType.number,
              ),
              _buildField("Address", addressController),
              _buildField(
                "Contact Email",
                emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveOrganizationInfo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      )
                    : const Text(
                        "SAVE ORGANIZATION",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) =>
            value == null || value.isEmpty ? "Enter $label" : null,
      ),
    );
  }
}
