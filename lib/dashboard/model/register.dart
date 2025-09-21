// import 'dart:convert';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart';
// import 'package:web3dart/web3dart.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
//
// class RegisterService {
//   final String _rpcUrl = "http://127.0.0.1:7545"; // Ganache RPC
//   final String _privateKey =
//       "0x298fcb664139fbfff9370c360c8cdc2058b118ee1c134ad94fbf38025419b2b2"; // From Ganache accounts
//   late Web3Client _client;
//   late EthPrivateKey _credentials;
//
//   RegisterService() {
//     _client = Web3Client(_rpcUrl, Client());
//     _credentials = EthPrivateKey.fromHex(_privateKey);
//   }
//
//   /// Load contract ABI + address
//   Future<DeployedContract> _loadContract(String name) async {
//     String abiString = await rootBundle.loadString(
//       "build/contracts/$name.json",
//     );
//     final jsonAbi = jsonDecode(abiString);
//     final abiCode = jsonEncode(jsonAbi["abi"]);
//     final contractAddr = EthereumAddress.fromHex(
//       jsonAbi["networks"]["5777"]["address"],
//     );
//
//     return DeployedContract(ContractAbi.fromJson(abiCode, name), contractAddr);
//   }
//
//   /// Call a contract function (write)
//   Future<String> _callFunction(
//     String contractName,
//     String functionName,
//     List<dynamic> args,
//   ) async {
//     final contract = await _loadContract(contractName);
//     final function = contract.function(functionName);
//
//     return await _client.sendTransaction(
//       _credentials,
//       Transaction.callContract(
//         contract: contract,
//         function: function,
//         parameters: args,
//       ),
//       fetchChainIdFromNetworkId: true,
//     );
//   }
//
//   /// Register with Firebase + Smart Contract
//   Future<String> registerUser({
//     required String email,
//     required String password,
//     required String role, // "organization" or "user"
//   }) async {
//     try {
//       // Firebase Authentication
//       UserCredential cred = await FirebaseAuth.instance
//           .createUserWithEmailAndPassword(email: email, password: password);
//
//       // Store user in Firebase Firestore
//       await FirebaseFirestore.instance
//           .collection("users")
//           .doc(cred.user!.uid)
//           .set({
//             "email": email,
//             "role": role,
//             "wallet": _credentials.address.hex,
//             "privateKey": _privateKey,
//           });
//
//       // Call smart contract register
//       final txHash = await _callFunction("Users", "registerUser", [
//         email,
//         role,
//       ]);
//
//       return "Registered successfully. TxHash: $txHash";
//     } catch (e) {
//       throw Exception("Registration failed: $e");
//     }
//   }
// }
