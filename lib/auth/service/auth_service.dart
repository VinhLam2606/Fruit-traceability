// lib/auth/service/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Global ValueNotifier để UI (AuthLayout) lắng nghe thay đổi
ValueNotifier<AuthService> authService = ValueNotifier(AuthService());

class AuthService extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  User? get currentUser => _firebaseAuth.currentUser;
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Trường dữ liệu chính
  String? decryptedPrivateKey; // dùng trực tiếp private_key từ Firestore
  String? walletAddress; // dùng trực tiếp eth_address
  String? accountType;
  String? username;

  // KEY CONSTANTS FOR SECURE STORAGE
  static const _privateKeyStorageKey = 'privateKey';
  static const _walletAddressStorageKey = 'walletAddress';

  AuthService() {
    authStateChanges.listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      decryptedPrivateKey = null;
      walletAddress = null;
      accountType = null;
      username = null;
      await _secureStorage.deleteAll();
      debugPrint("🔒 [AuthState] Đã đăng xuất → Xóa key khỏi bộ nhớ an toàn.");
    } else {
      debugPrint("🔓 [AuthState] Người dùng ${user.email} đã đăng nhập.");
      await _loadKeyFromSecureStorage();

      // 🔑 Nếu storage rỗng thì thử lấy lại từ Firestore
      if (decryptedPrivateKey == null || walletAddress == null) {
        try {
          final doc = await _firestore.collection('users').doc(user.uid).get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            decryptedPrivateKey = data['private_key'];
            walletAddress = data['eth_address'];
            accountType = data['accountType'];
            username = data['username'];

            // Lưu lại vào SecureStorage
            if (decryptedPrivateKey != null) {
              await _secureStorage.write(
                key: _privateKeyStorageKey,
                value: decryptedPrivateKey,
              );
            }
            if (walletAddress != null) {
              await _secureStorage.write(
                key: _walletAddressStorageKey,
                value: walletAddress,
              );
            }
            debugPrint("✅ [AuthState] Lấy key từ Firestore do storage rỗng.");
          }
        } catch (e) {
          debugPrint("❌ [AuthState] Lỗi khi tải Firestore fallback: $e");
        }
      }
    }

    debugPrint("📊 [AuthState] accountType=$accountType, username=$username");
    authService.value = this;
    notifyListeners();
  }

  Future<void> _loadKeyFromSecureStorage() async {
    try {
      decryptedPrivateKey = await _secureStorage.read(
        key: _privateKeyStorageKey,
      );
      walletAddress = await _secureStorage.read(key: _walletAddressStorageKey);
      if (decryptedPrivateKey != null) {
        debugPrint("✅ [Storage] Tải private key thành công.");
      } else {
        debugPrint("⚠️ [Storage] Không tìm thấy private key.");
      }
      debugPrint("📦 [Storage] walletAddress=$walletAddress");
    } catch (e) {
      debugPrint("❌ [Storage] Lỗi khi tải key: $e");
    }
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    debugPrint("➡️ [SignIn] Bắt đầu đăng nhập với $email");
    final userCred = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userCred.user!.uid)
          .get();

      if (!doc.exists || doc.data() == null) {
        throw Exception("Không tìm thấy tài liệu người dùng trong Firestore.");
      }

      final data = doc.data()!;
      final privateKey = data['private_key'];
      final walletAddr = data['eth_address'];
      final type = data['accountType'];
      final name = data['username'];

      debugPrint(
        "📄 [Firestore] Tải dữ liệu user: "
        "username=$name, accountType=$type, "
        "address=$walletAddr",
      );

      if (privateKey == null || walletAddr == null) {
        throw Exception("❌ Firestore thiếu private_key hoặc eth_address.");
      }

      // 🔑 Lưu trực tiếp vào Secure Storage
      await _secureStorage.write(key: _privateKeyStorageKey, value: privateKey);
      await _secureStorage.write(
        key: _walletAddressStorageKey,
        value: walletAddr,
      );

      debugPrint(
        "🔑 [Storage] Đã lưu private_key & address vào SecureStorage.",
      );

      // ✅ Cập nhật state
      decryptedPrivateKey = privateKey;
      walletAddress = walletAddr;
      username = name;
      accountType = type;

      debugPrint("📊 [SignIn] username=$username, accountType=$accountType");

      authService.value = this;
      notifyListeners();

      return userCred;
    } catch (e) {
      debugPrint("❌ [SignIn] Lỗi khi lấy Firestore data: $e");
      await signOut();
      rethrow;
    }
  }

  Future<UserCredential> createAccount({
    required String email,
    required String password,
  }) async {
    debugPrint("🆕 [CreateAccount] Tạo tài khoản với $email");
    return await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    debugPrint("🚪 [SignOut] Đăng xuất");
    await _firebaseAuth.signOut();
  }

  // ✅ Setter userData để gán toàn bộ dữ liệu từ Firestore hoặc blockchain
  set userData(Map<String, dynamic> data) {
    decryptedPrivateKey = data['private_key'];
    walletAddress = data['eth_address'];
    username = data['username'];
    accountType = data['accountType'];

    // Lưu vào SecureStorage để lần sau đăng nhập tự load lại
    if (decryptedPrivateKey != null) {
      _secureStorage.write(
        key: _privateKeyStorageKey,
        value: decryptedPrivateKey,
      );
    }
    if (walletAddress != null) {
      _secureStorage.write(key: _walletAddressStorageKey, value: walletAddress);
    }

    debugPrint("📝 [UserData] Gán dữ liệu Firestore/Blockchain:");
    debugPrint("   username=$username, accountType=$accountType");
    debugPrint("   walletAddress=$walletAddress");

    authService.value = this;
    notifyListeners();
  }
}
