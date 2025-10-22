import 'dart:developer' as developer;

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
  String? decryptedPrivateKey;
  String? walletAddress;
  String? accountType;
  String? username;
  // 🔥 THÊM CỜ MỚI
  bool? isOrganizationDetailsSubmitted;

  // KEY CONSTANTS FOR SECURE STORAGE
  static const _privateKeyStorageKey = 'privateKey';
  static const _walletAddressStorageKey = 'walletAddress';
  // 🔥 THÊM KEYS MỚI
  static const _accountTypeStorageKey = 'accountType';
  static const _usernameStorageKey = 'username';
  static const _orgDetailsSubmittedKey = 'isOrganizationDetailsSubmitted';

  AuthService() {
    authStateChanges.listen(_onAuthStateChanged);
  }

  // =======================================================================
  // 🔥 LOGIC _onAuthStateChanged ĐÃ ĐƯỢC CẬP NHẬT HOÀN TOÀN
  // =======================================================================
  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      // Khi người dùng đăng xuất, xóa toàn bộ state và storage
      decryptedPrivateKey = null;
      walletAddress = null;
      accountType = null;
      username = null;
      isOrganizationDetailsSubmitted = null; // 🔥 Xóa cờ
      await _secureStorage.deleteAll();
      developer.log(
        "🔒 [AuthState] Đã đăng xuất → Xóa key khỏi bộ nhớ an toàn.",
      );
    } else {
      developer.log("🔓 [AuthState] Người dùng ${user.email} đã đăng nhập.");
      // Luôn thử tải tất cả dữ liệu từ storage trước
      await _loadKeyFromSecureStorage();

      // Nếu một trong các dữ liệu quan trọng bị thiếu, hãy lấy lại từ Firestore
      if (decryptedPrivateKey == null ||
          walletAddress == null ||
          accountType == null ||
          username == null ||
          (accountType == 'organization' &&
              isOrganizationDetailsSubmitted == null)) {
        developer.log(
          "⚠️ [AuthState] Dữ liệu trong storage chưa đủ, đang lấy từ Firestore...",
        );
        try {
          final doc = await _firestore.collection('users').doc(user.uid).get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            // Cập nhật state từ Firestore
            decryptedPrivateKey = data['private_key'];
            walletAddress = data['eth_address'];
            accountType = data['accountType'];
            username = data['username'];
            // 🔥 Lấy cờ từ firestore
            isOrganizationDetailsSubmitted =
                data['isOrganizationDetailsSubmitted'];

            // Lưu lại toàn bộ dữ liệu vào SecureStorage
            await _saveAllDataToSecureStorage(
              privateKey: decryptedPrivateKey,
              walletAddress: walletAddress,
              accountType: accountType,
              username: username,
              isOrganizationDetailsSubmitted: isOrganizationDetailsSubmitted,
            );
            developer.log(
              "✅ [AuthState] Lấy và lưu lại toàn bộ dữ liệu từ Firestore.",
            );
          } else {
            // 🔥 THÊM: Ghi log nếu không tìm thấy doc (trường hợp race condition)
            developer.log(
              "ℹ️ [AuthState] Không tìm thấy doc Firestore khi auth state thay đổi (có thể user đang đăng ký).",
            );
          }
        } catch (e) {
          developer.log("❌ [AuthState] Lỗi khi tải Firestore fallback: $e");
        }
      } else {
        developer.log(
          "✅ [AuthState] Tải thành công toàn bộ dữ liệu từ storage.",
        );
      }
    }

    developer.log(
      "📊 [AuthState] state: accountType=$accountType, username=$username, orgSubmitted=$isOrganizationDetailsSubmitted",
    );
    authService.value = this; // Đảm bảo value được cập nhật
    notifyListeners();
  }

  // =======================================================================
  // 🔥 HÀM _loadKeyFromSecureStorage ĐÃ ĐƯỢC CẬP NHẬT
  // =======================================================================
  Future<void> _loadKeyFromSecureStorage() async {
    try {
      decryptedPrivateKey = await _secureStorage.read(
        key: _privateKeyStorageKey,
      );
      walletAddress = await _secureStorage.read(key: _walletAddressStorageKey);
      accountType = await _secureStorage.read(key: _accountTypeStorageKey);
      username = await _secureStorage.read(key: _usernameStorageKey);

      // 🔥 Tải cờ (lưu dưới dạng string 'true'/'false')
      final orgDetailsString = await _secureStorage.read(
        key: _orgDetailsSubmittedKey,
      );
      isOrganizationDetailsSubmitted = orgDetailsString == null
          ? null
          : (orgDetailsString == 'true');

      developer.log(
        "✅ [Storage] Tải dữ liệu từ storage: username=$username, type=$accountType, orgSubmitted=$isOrganizationDetailsSubmitted",
      );
    } catch (e) {
      developer.log("❌ [Storage] Lỗi khi tải key: $e");
    }
  }

  // Hàm helper để lưu tất cả dữ liệu vào storage
  Future<void> _saveAllDataToSecureStorage({
    String? privateKey,
    String? walletAddress,
    String? accountType,
    String? username,
    bool? isOrganizationDetailsSubmitted, // 🔥 Thêm tham số
  }) async {
    if (privateKey != null)
      await _secureStorage.write(key: _privateKeyStorageKey, value: privateKey);
    if (walletAddress != null)
      await _secureStorage.write(
        key: _walletAddressStorageKey,
        value: walletAddress,
      );
    if (accountType != null)
      await _secureStorage.write(
        key: _accountTypeStorageKey,
        value: accountType,
      );
    if (username != null)
      await _secureStorage.write(key: _usernameStorageKey, value: username);

    // 🔥 Lưu cờ
    if (isOrganizationDetailsSubmitted != null)
      await _secureStorage.write(
        key: _orgDetailsSubmittedKey,
        value: isOrganizationDetailsSubmitted.toString(),
      );
  }

  // =======================================================================
  // 🔥 HÀM signIn ĐÃ ĐƯỢC CẬP NHẬT
  // =======================================================================
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    developer.log("➡️ [SignIn] Bắt đầu đăng nhập với $email");
    try {
      final userCred = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final doc = await _firestore
          .collection('users')
          .doc(userCred.user!.uid)
          .get();

      if (!doc.exists || doc.data() == null) {
        throw Exception("Không tìm thấy tài liệu người dùng trong Firestore.");
      }

      final data = doc.data()!;
      final pKey = data['private_key'];
      final walletAddr = data['eth_address'];
      final type = data['accountType'];
      final name = data['username'];
      // 🔥 Lấy cờ
      final orgDetails = data['isOrganizationDetailsSubmitted'] as bool?;

      developer.log(
        "📄 [Firestore] Tải dữ liệu user: username=$name, accountType=$type, orgSubmitted=$orgDetails",
      );

      if (pKey == null || walletAddr == null) {
        throw Exception("❌ Firestore thiếu private_key hoặc eth_address.");
      }

      // 🔑 Lưu toàn bộ vào Secure Storage
      await _saveAllDataToSecureStorage(
        privateKey: pKey,
        walletAddress: walletAddr,
        accountType: type,
        username: name,
        isOrganizationDetailsSubmitted: orgDetails, // 🔥 Lưu cờ
      );
      developer.log("🔑 [Storage] Đã lưu toàn bộ dữ liệu vào SecureStorage.");

      // ✅ Cập nhật state
      decryptedPrivateKey = pKey;
      walletAddress = walletAddr;
      username = name;
      accountType = type;
      isOrganizationDetailsSubmitted = orgDetails; // 🔥 Cập nhật cờ

      authService.value = this;
      notifyListeners();

      return userCred;
    } catch (e) {
      developer.log("❌ [SignIn] Lỗi khi lấy Firestore data: $e");
      await signOut(); // Đăng xuất nếu có lỗi để tránh trạng thái kẹt
      rethrow;
    }
  }

  Future<UserCredential> createAccount({
    required String email,
    required String password,
  }) async {
    developer.log("🆕 [CreateAccount] Tạo tài khoản với $email");
    return await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<Map<String, String>?> getUserWalletByEmail(String email) async {
    try {
      developer.log("🔎 [AuthService] Đang tìm user theo email: $email");

      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        developer.log("⚠️ [AuthService] Không tìm thấy user với email: $email");
        return null;
      }

      final userDoc = querySnapshot.docs.first.data();

      final privateKey = userDoc['private_key'] as String?;
      final walletAddr = userDoc['eth_address'] as String?;
      final username = userDoc['username'] as String?;

      if (privateKey == null || walletAddr == null) {
        developer.log(
          "❌ [AuthService] User thiếu private_key hoặc eth_address",
        );
        return null;
      }

      developer.log("✅ [AuthService] Tìm thấy user: $username ($walletAddr)");

      return {
        'private_key': privateKey,
        'eth_address': walletAddr,
        'username': username ?? '',
      };
    } catch (e) {
      developer.log("❌ [AuthService] Lỗi khi lấy user theo email: $e");
      return null;
    }
  }

  Future<String?> getUsernameByAddress(String ethAddress) async {
    try {
      developer.log(
        "🔎 [AuthService] Đang tìm username theo address: $ethAddress",
      );

      final querySnapshot = await _firestore
          .collection('users')
          .where('eth_address', isEqualTo: ethAddress.toLowerCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        developer.log(
          "⚠️ [AuthService] Không tìm thấy user với address: $ethAddress",
        );
        return null;
      }

      final username = querySnapshot.docs.first.data()['username'] as String?;

      developer.log("✅ [AuthService] Tìm thấy username: $username");
      return username;
    } catch (e) {
      developer.log("❌ [AuthService] Lỗi khi lấy username theo address: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getOrganizationDetailsByAddress(
    String ethAddress,
  ) async {
    try {
      developer.log(
        "🔎 [AuthService] Đang tìm chi tiết tổ chức theo address: $ethAddress",
      );
      final querySnapshot = await _firestore
          .collection('organizations')
          .where('eth_address', isEqualTo: ethAddress.toLowerCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        developer.log(
          "✅ [AuthService] Tìm thấy dữ liệu tổ chức trên Firebase.",
        );
        return querySnapshot.docs.first.data();
      }
      developer.log(
        "⚠️ [AuthService] Không tìm thấy dữ liệu tổ chức trên Firebase cho địa chỉ: $ethAddress",
      );
      return null;
    } catch (e) {
      developer.log("❌ Lỗi khi lấy chi tiết tổ chức từ Firebase: $e");
      return null;
    }
  }

  // 🔥 ================== BƯỚC 1 (SỬA LỖI): THÊM HÀM MỚI ==================
  /// Cập nhật state khi tổ chức điền form,
  /// đảm bảo lưu cả vào bộ nhớ (state) và bộ nhớ an toàn (storage)
  Future<void> markOrganizationDetailsAsSubmitted(String newUsername) async {
    developer.log(
      "🔄 [AuthService] Đánh dấu tổ chức đã nộp form, username=$newUsername",
    );

    // 1. Cập nhật state trong bộ nhớ (in-memory)
    isOrganizationDetailsSubmitted = true;
    username = newUsername;

    try {
      // 2. Cập nhật state vào bộ nhớ an toàn (Secure Storage)
      // Rất quan trọng: Phải lưu lại tất cả các key khác
      await _saveAllDataToSecureStorage(
        privateKey: decryptedPrivateKey,
        walletAddress: walletAddress,
        accountType: accountType,
        username: username, // Lưu username mới
        isOrganizationDetailsSubmitted:
            isOrganizationDetailsSubmitted, // Lưu cờ mới
      );

      developer.log(
        "✅ [AuthService] Đã cập nhật SecureStorage: orgSubmitted=true, username=$newUsername",
      );

      // 3. Thông báo cho UI (AuthLayout) rebuild
      // Gán lại .value để ValueNotifier chắc chắn nhận được thay đổi
      authService.value = this;
      notifyListeners();
    } catch (e) {
      developer.log(
        "❌ [AuthService] Lỗi khi lưu cờ orgSubmitted vào SecureStorage: $e",
      );
    }
  }
  // 🔥 ===================================================================

  Future<void> signOut() async {
    developer.log("🚪 [SignOut] Đăng xuất");
    await _firebaseAuth.signOut();
    // Logic xóa đã được chuyển vào _onAuthStateChanged
  }

  // 🔥🔥 SỬA LỖI: CẬP NHẬT CÁC TRƯỜNG STATE CỤC BỘ 🔥🔥
  set userData(Map<String, dynamic> data) {
    // Cập nhật các trường state của instance
    decryptedPrivateKey = data['private_key'];
    walletAddress = data['eth_address'];
    username = data['username'];
    accountType = data['accountType'];
    isOrganizationDetailsSubmitted =
        data['isOrganizationDetailsSubmitted']; // 🔥 Thêm cờ

    // Lưu vào SecureStorage để lần sau đăng nhập tự load lại
    _saveAllDataToSecureStorage(
      privateKey: decryptedPrivateKey,
      walletAddress: walletAddress,
      username: username,
      accountType: accountType,
      isOrganizationDetailsSubmitted:
          isOrganizationDetailsSubmitted, // 🔥 Thêm cờ
    );

    developer.log("📝 [UserData] Gán dữ liệu Firestore/Blockchain:");
    developer.log(
      "   username=$username, accountType=$accountType, orgSubmitted=$isOrganizationDetailsSubmitted",
    );
    developer.log("   walletAddress=$walletAddress");

    // Thông báo cho ValueListenableBuilder (trong AuthLayout)
    authService.value = this;
    notifyListeners();
  }
}
