// ignore_for_file: file_names
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hd_wallet_kit/hd_wallet_kit.dart';
import 'package:hd_wallet_kit/utils.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

/// ----------------------
/// 🔹 HD Wallet Extensions
/// ----------------------
extension HDWalletPathExt on HDWallet {
  /// Forwarder to hd_wallet_kit’s real API
  HDKey deriveChildKeyByPath(String path) {
    return deriveKeyByPath(path: path);
  }
}

extension HDKeyPrivateExt on HDKey {
  /// Safely extract private key bytes
  Uint8List get privateKeyBytes {
    final pk = privKeyBytes;
    if (pk == null || pk.isEmpty) {
      throw Exception("No private key available in this HDKey");
    }
    return (pk.length == 33 && pk[0] == 0)
        ? pk.sublist(1)
        : Uint8List.fromList(pk);
  }

  /// Convert private key to hex with 0x prefix
  String get privateKeyHex0x {
    final raw = privateKeyBytes;
    return '0x${uint8ListToHexString(raw)}';
  }
}

/// ----------------------
/// 🔹 Ethereum Utilities
/// ----------------------

late Web3Client ethClient;
DeployedContract? usersContract;

/// Initialize Web3 client and contract
Future<void> initContract() async {
  ethClient = Web3Client("http://192.168.102.5:7545", http.Client());
  try {
    final abiJson = jsonDecode(
      await rootBundle.loadString("build/contracts/Chain.json"),
    );
    final abi = jsonEncode(abiJson["abi"]);
    const networkId = "5777";
    final contractAddr = EthereumAddress.fromHex(
      abiJson["networks"][networkId]["address"],
    );

    usersContract = DeployedContract(
      ContractAbi.fromJson(abi, "Chain"),
      contractAddr,
    );
    print("✅ Chain contract loaded at $contractAddr");
  } catch (e) {
    print("⚠️ Failed to load Chain contract: $e");
    rethrow;
  }
}

/// Add organization on blockchain
Future<String> addOrganizationOnChain(
  String orgName,
  EthPrivateKey senderKey,
) async {
  if (usersContract == null) await initContract();
  final fn = usersContract!.function("addOrganization");

  final txHash = await ethClient.sendTransaction(
    senderKey,
    Transaction.callContract(
      contract: usersContract!,
      function: fn,
      parameters: [orgName, BigInt.from(DateTime.now().millisecondsSinceEpoch)],
    ),
    chainId: 1337,
  );

  print("🏢 Blockchain: addOrganization txHash=$txHash");
  return txHash;
}

/// Wait for transaction confirmation
Future<void> waitForTxConfirmation(String txHash) async {
  print("⏳ Waiting for tx $txHash to be mined...");
  while (true) {
    final receipt = await ethClient.getTransactionReceipt(txHash);
    if (receipt != null) {
      print("✅ Transaction confirmed: $txHash");
      break;
    }
    await Future.delayed(const Duration(seconds: 2));
  }
}
