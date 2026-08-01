import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper over platform secure storage for the auth token + cached session.
class SecureStore {
  SecureStore._();
  static final SecureStore instance = SecureStore._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kToken = 'slk_token';
  static const _kSession = 'slk_session';

  Future<String?> readToken() => _storage.read(key: _kToken);
  Future<void> writeToken(String token) => _storage.write(key: _kToken, value: token);

  Future<String?> readSession() => _storage.read(key: _kSession);
  Future<void> writeSession(String json) => _storage.write(key: _kSession, value: json);

  Future<void> clear() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kSession);
  }
}
