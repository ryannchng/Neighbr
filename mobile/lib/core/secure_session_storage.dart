import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stores the Supabase session in the OS keychain / EncryptedSharedPreferences
/// instead of plain SharedPreferences.
///
/// - Android: EncryptedSharedPreferences (AES-256)
/// - iOS/macOS: Keychain (first-unlock accessibility)
class SecureSessionStorage extends LocalStorage {
  static const _key = 'supabase_session';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  @override
  Future<void> initialize() async {
    // Nothing to set up — FlutterSecureStorage is ready immediately.
  }

  @override
  Future<bool> hasAccessToken() async {
    return _storage.containsKey(key: _key);
  }

  @override
  Future<String?> accessToken() async {
    return _storage.read(key: _key);
  }

  @override
  Future<void> removePersistedSession() async {
    await _storage.delete(key: _key);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _storage.write(key: _key, value: persistSessionString);
  }
}