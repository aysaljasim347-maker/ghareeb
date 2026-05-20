import 'package:reliefnet_app/features/auth/domain/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Provider for secure storage service.
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Wrapper around flutter_secure_storage for JWT and user data.
class SecureStorageService {
  static const _tokenKey = 'auth_token';
  static const _userRoleKey = 'user_role';
  static const _userIdKey = 'user_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ── Token ──

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // ── User Role ──

  Future<void> saveUserRole(UserRole role) async {
    await _storage.write(key: _userRoleKey, value: role.value);
  }

  Future<String?> getUserRole() async {
    return _storage.read(key: _userRoleKey);
  }

  // ── User ID ──

  Future<void> saveUserId(String id) async {
    await _storage.write(key: _userIdKey, value: id);
  }

  Future<String?> getUserId() async {
    return _storage.read(key: _userIdKey);
  }

  // ── Clear All ──

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
