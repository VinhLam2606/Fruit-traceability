import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:untitled/auth/service/auth_service.dart';
import 'package:untitled/auth/service/walletExt_service.dart';
import 'package:untitled/auth/auth_layout.dart';
import 'package:web3dart/credentials.dart';

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
  final foundedYearController = TextEditingController();
  final addressController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  bool _isSaving = false;

  // Danh sách loại hình doanh nghiệp
  final List<String> _businessTypes = [
    'LLC',
    'Corporation',
    'Partnership',
    'Sole Proprietorship',
    'Cooperative',
    'Non-profit',
    'Other',
  ];

  String? _selectedBusinessType;

  @override
  void dispose() {
    fullNameController.dispose();
    brandController.dispose();
    foundedYearController.dispose();
    addressController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveOrganizationInfo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("No user logged in.");

      // 1️⃣ Lưu thông tin tổ chức vào Firestore
      await FirebaseFirestore.instance.collection("organizations").doc(uid).set({
        "fullName": fullNameController.text.trim(),
        "brandName": brandController.text.trim(),
        "businessType": _selectedBusinessType,
        "foundedYear": foundedYearController.text.trim(),
        "address": addressController.text.trim(),
        "phoneNumber": phoneController.text.trim(),
        "email": emailController.text.trim(),
        "eth_address": widget.ethAddress.toLowerCase(),
        "private_key": widget.privateKey,
        "createdAt": FieldValue.serverTimestamp(),
      });

      // 2️⃣ Lấy private key user từ Firestore
      final userDoc =
          await FirebaseFirestore.instance.collection("users").doc(uid).get();
      final privateKey = userDoc["private_key"] as String?;
      if (privateKey == null || privateKey.isEmpty) {
        throw Exception("Private key not found for this user!");
      }

      // 3️⃣ Ghi dữ liệu lên blockchain
      await initContract(); // Hàm có sẵn trong walletExt_service.dart
      final credentials = EthPrivateKey.fromHex(privateKey);
      final walletAddress = await credentials.extractAddress();

      final fnCheck = usersContract!.function("getOrganization");
      final result = await ethClient.call(
        contract: usersContract!,
        function: fnCheck,
        params: [walletAddress],
      );

      final orgData = result.first as List<dynamic>;
      final orgName = orgData[0] as String;

      if (orgName.isNotEmpty) {
        print("🟡 Organization already exists on-chain, skip.");
      } else {
        final txHash = await addOrganizationOnChain(
          brandController.text.trim(),
          credentials,
        );
        print("✅ On-chain organization registered: $txHash");
      }

      // 4️⃣ Cập nhật cờ và username trong Firestore
      final newUsername = fullNameController.text.trim();
      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "isOrganizationDetailsSubmitted": true,
        "username": newUsername,
      });

      // 5️⃣ Cập nhật state trong AuthService và lưu lại SecureStorage
      await authService.value
          .markOrganizationDetailsAsSubmitted(newUsername);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Tổ chức đã đăng ký thành công!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // ✅ Điều hướng về trang chủ
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthLayout()),
          (route) => false,
        );
      }
    } catch (e) {
      print("❌ Failed to save organization: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Lưu tổ chức thất bại: $e"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSaving = false);
      }
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
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<String>(
                  value: _selectedBusinessType,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: const Color(0xFF243B55),
                  decoration: InputDecoration(
                    labelText: "Business Type",
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: _businessTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() => _selectedBusinessType = newValue);
                  },
                  validator: (value) =>
                      value == null ? "Please select a business type" : null,
                ),
              ),
              _buildField(
                "Founded Year",
                foundedYearController,
                keyboardType: TextInputType.number,
              ),
              _buildField("Address", addressController),
              _buildField(
                "Phone Number",
                phoneController,
                keyboardType: TextInputType.phone,
              ),
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
