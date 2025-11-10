import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:untitled/dashboard/bloc/dashboard_bloc.dart';
import 'package:untitled/dashboard/bloc/scan_bloc.dart';
// ✅ Import thêm BLoC quản lý thông tin tổ chức
import 'package:untitled/dashboard/bloc/user_organization_bloc.dart';
import 'package:untitled/navigation/customer_navigation.dart';
import 'package:untitled/navigation/main_navigation.dart';
import 'package:web3dart/web3dart.dart';

import 'service/auth_service.dart';
import 'ui/login_or_register_page.dart';
import 'ui/organization_form_page.dart'; // 🔥 Import trang form

class AppLoadingPage extends StatelessWidget {
  const AppLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key});

  // 🔹 Hàm tải contract Chain (đọc ABI + address)
  Future<DeployedContract> _loadChainContract(BuildContext context) async {
    final abiString = await DefaultAssetBundle.of(
      context,
    ).loadString("build/contracts/Chain.json");
    final jsonAbi = jsonDecode(abiString);
    final abi = ContractAbi.fromJson(jsonEncode(jsonAbi['abi']), 'Chain');
    final networkKey = (jsonAbi['networks'] as Map<String, dynamic>).keys.first;
    final contractAddressHex = jsonAbi['networks'][networkKey]['address'];
    final contractAddress = EthereumAddress.fromHex(contractAddressHex);
    return DeployedContract(abi, contractAddress);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthService>(
      valueListenable: authService,
      builder: (context, service, _) {
        // Nếu chưa đăng nhập hoặc chưa có key thì quay lại login
        if (service.currentUser == null ||
            service.decryptedPrivateKey == null ||
            service.walletAddress == null) {
          return const LoginOrRegisterPage();
        }

        // Tạo Web3 client
        final rpcUrl = "http://10.248.229.189:7545"; // 🔧 Ganache mặc định
        final web3client = Web3Client(rpcUrl, http.Client());
        final credentials = EthPrivateKey.fromHex(service.decryptedPrivateKey!);

        // ✅ Cung cấp tất cả BLoC cần thiết
        return MultiBlocProvider(
          providers: [
            BlocProvider<DashboardBloc>(
              create: (_) => DashboardBloc(
                web3client: web3client,
                credentials: credentials,
              )..add(DashboardInitialFetchEvent()),
            ),
            BlocProvider<ScanBloc>(
              create: (_) =>
                  ScanBloc(web3client: web3client, credentials: credentials),
            ),
            BlocProvider<UserOrganizationBloc>(
              create: (_) => UserOrganizationBloc(
                web3client: web3client,
                credentials: credentials,
              )..add(FetchUserOrganization()),
            ),
          ],
          child: Builder(
            builder: (context) {
              final accountType = service.accountType;
              final bool isOrgDetailsSubmitted =
                  service.isOrganizationDetailsSubmitted ?? false;

              // 🔹 Tổ chức (organization)
              if (accountType == "organization") {
                if (isOrgDetailsSubmitted) {
                  // Đã điền form tổ chức → vào main app
                  return const MainNavigationPage();
                } else {
                  // Chưa điền form tổ chức → bắt buộc điền
                  return FutureBuilder<DeployedContract>(
                    future: _loadChainContract(context),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting ||
                          !snapshot.hasData) {
                        return const AppLoadingPage();
                      }
                      if (snapshot.hasError) {
                        return Scaffold(
                          body: Center(
                            child: Text("Lỗi tải contract: ${snapshot.error}"),
                          ),
                        );
                      }
                      return OrganizationFormPage(
                        ethAddress: service.walletAddress!,
                        privateKey: service.decryptedPrivateKey!,
                      );
                    },
                  );
                }
              }
              // 🔹 Người dùng (user)
              else if (accountType == "user") {
                return FutureBuilder<DeployedContract>(
                  future: _loadChainContract(context),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting ||
                        !snapshot.hasData) {
                      return const AppLoadingPage();
                    }
                    if (snapshot.hasError) {
                      return Scaffold(
                        body: Center(
                          child: Text("Lỗi tải contract: ${snapshot.error}"),
                        ),
                      );
                    }
                    return CustomerNavigationPage(
                      web3client: web3client,
                      deployedContract: snapshot.data!,
                      credentials: credentials,
                    );
                  },
                );
              }

              // 🔹 Nếu có lỗi hoặc chưa xác định → quay lại login
              return const LoginOrRegisterPage();
            },
          ),
        );
      },
    );
  }
}
