import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:untitled/auth/auth_layout.dart';
import 'package:untitled/auth/bloc/auth_bloc.dart';
import 'package:untitled/auth/bloc/auth_event.dart';
import 'package:untitled/auth/bloc/auth_state.dart';
import 'package:untitled/auth/ui/organization_form_page.dart';

class VerifyEmailPage extends StatelessWidget {
  final String email;
  final String accountType; // 👈 thêm
  final String username;
  const VerifyEmailPage({
    super.key,
    required this.email,
    required this.accountType,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141E30),
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
  if (state is AuthSuccess) {
    if (state.accountType == "organization") {
      // 👇 Nếu là tổ chức → mở form điền thông tin
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrganizationFormPage(
            ethAddress: AuthBloc.providedAddress,
            privateKey: AuthBloc.providedPrivateKey,
          ),
        ),
      );
    } else {
      // 👇 Nếu là người dùng thường → về thẳng trang chủ
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthLayout()),
      );
    }
  } else if (state is AuthFailure) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("❌ ${state.message}"),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
},

          builder: (context, state) {
            final isLoading = state is AuthLoading;

            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      size: 100,
                      color: Colors.greenAccent,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Xác minh email của bạn",
                      style: const TextStyle(
                        fontSize: 26,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Một email xác minh đã được gửi đến:",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () {
                              context.read<AuthBloc>().add(
                                AuthEmailVerificationChecked(
                                  email,
                                  accountType, 
                                  username, 
                                ),
                              );
                            },
                      icon: const Icon(Icons.verified, color: Colors.black),
                      label: isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              "Tôi đã xác minh email",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "← Quay lại đăng ký",
                        style: TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
