import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Dónde vive el refresh token entre arranques (A-004). El access token nunca se persiste.
abstract interface class TokenStore {
  Future<String?> readRefreshToken();

  Future<void> writeRefreshToken(String token);

  Future<void> clear();
}

/// Keychain (iOS) / Keystore (Android) / almacenamiento del navegador (web).
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'hogar.refreshToken';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _key);

  @override
  Future<void> writeRefreshToken(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Para tests.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.token]);

  String? token;

  @override
  Future<String?> readRefreshToken() async => token;

  @override
  Future<void> writeRefreshToken(String token) async => this.token = token;

  @override
  Future<void> clear() async => token = null;
}
