import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:untitled/dashboard/bloc/dashboard_bloc.dart';
import 'package:untitled/navigation/customer_navigation.dart';
import 'package:untitled/navigation/main_navigation.dart';
import 'package:untitled/dashboard/bloc/scan_bloc.dart';
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

  // Đổi tên hàm để rõ ràng hơn, nó tải contract "Chain"
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
        if (service.currentUser == null ||
            service.decryptedPrivateKey == null ||
            service.walletAddress == null) {
          return const LoginOrRegisterPage();
        }

        final rpcUrl = "http://10.0.2.2:7545";
        final web3client = Web3Client(rpcUrl, http.Client());
        final credentials = EthPrivateKey.fromHex(service.decryptedPrivateKey!);
        final accountType = service.accountType;

        if (accountType == "organization") {
          // 🏢 Tổ chức → Cung cấp DashboardBloc, MainNavigationPage sẽ cung cấp các BLoC con
          return BlocProvider<DashboardBloc>(
            create: (_) => DashboardBloc(
              web3client: web3client,
              credentials: credentials,
            )..add(DashboardInitialFetchEvent()),
            child: const MainNavigationPage(),
          );
        } else if (accountType == "user") {
          // 👤 Customer → Cung cấp ScanBloc, sau đó tải contract cho CustomerNavigationPage
          return BlocProvider<ScanBloc>(
            create: (_) => ScanBloc(web3client: web3client, credentials: credentials),
            child: FutureBuilder<DeployedContract>(
              future: _loadChainContract(context),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
                  return const AppLoadingPage();
                }
                if (snapshot.hasError) {
                  return Scaffold(body: Center(child: Text("Lỗi tải contract: ${snapshot.error}")));
                }
                return CustomerNavigationPage(
                  web3client: web3client,
                  deployedContract: snapshot.data!,
                );
              },
            ),
          );
        }

        return const LoginOrRegisterPage();
      },
    );
  }
}