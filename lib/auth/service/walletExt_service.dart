// ignore_for_file: file_names
import 'dart:typed_data';
import 'package:hd_wallet_kit/hd_wallet_kit.dart';
import 'package:hd_wallet_kit/utils.dart';

extension HDWalletPathExt on HDWallet {
  /// Forwarder to hd_wallet_kit’s real API
  /// Correct call is deriveKeyByPath(path: ...)
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
