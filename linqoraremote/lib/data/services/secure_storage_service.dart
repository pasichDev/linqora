import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages sensitive values that must not be stored in plain-text storage.
///
/// Currently holds the HMAC shared secret used for challenge-response
/// authentication with the LinqoraHost server.
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keySharedSecret = 'linqora_shared_secret';

  /// Persists [secret] to the platform keystore.
  static Future<void> saveSharedSecret(String secret) async {
    await _storage.write(key: _keySharedSecret, value: secret);
  }

  /// Reads the stored shared secret, or `null` if none has been saved.
  static Future<String?> getSharedSecret() async {
    return _storage.read(key: _keySharedSecret);
  }

  /// Removes the stored shared secret.
  static Future<void> deleteSharedSecret() async {
    await _storage.delete(key: _keySharedSecret);
  }

  /// Returns `true` if a non-empty shared secret is stored.
  static Future<bool> hasSharedSecret() async {
    final val = await _storage.read(key: _keySharedSecret);
    return val != null && val.isNotEmpty;
  }
}
