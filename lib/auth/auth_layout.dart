import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:untitled/dashboard/bloc/dashboard_bloc.dart';
import 'package:untitled/navigation/customer_navigation.dart';
import 'package:untitled/navigation/main_navigation.dart';
import 'package:web3dart/web3dart.dart';

import 'service/auth_service.dart';
import 'ui/login_or_register_page.dart';

class AppLoadingPage extends StatelessWidget {
  const AppLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key});

  Future<DeployedContract> _loadContract(BuildContext context) async {
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
        // --- 1. Nếu chưa đăng nhập ---
        if (service.currentUser == null) {
          return const LoginOrRegisterPage();
        }

        // --- 2. Nếu chưa load private key hoặc wallet ---
        if (service.decryptedPrivateKey == null ||
            service.walletAddress == null) {
          return const LoginOrRegisterPage();
        }

        // --- 3. Nếu đã đăng nhập ---
        final rpcUrl = "http://10.0.2.2:7545";
        final web3client = Web3Client(rpcUrl, http.Client());
        final credentials = EthPrivateKey.fromHex(service.decryptedPrivateKey!);
        final accountType = service.accountType;

        if (accountType == "organization") {
          // 🏢 Tổ chức → DashboardBloc + MainNavigationPage
          return BlocProvider(
            create: (_) =>
                DashboardBloc(web3client: web3client, credentials: credentials)
                  ..add(DashboardInitialFetchEvent()),
            child: const MainNavigationPage(),
          );
        } else if (accountType == "user") {
          // 👤 Customer → CustomerNavigationPage
          return FutureBuilder<DeployedContract>(
            future: _loadContract(context),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const AppLoadingPage();
              }
              return CustomerNavigationPage(
                web3client: web3client,
                deployedContract: snapshot.data!,
              );
            },
          );
        }

        // 🚫 Nếu accountType khác
        return const LoginOrRegisterPage();
      },
    );
  }
}
