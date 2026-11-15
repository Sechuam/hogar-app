import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';

class User {
  const User({required this.id, required this.email, required this.displayName});

  factory User.fromJson(Json json) =>
      User(id: json['id'] as String, email: json['email'] as String, displayName: json['displayName'] as String);

  final String id;
  final String email;
  final String displayName;
}

/// Registro, login y logout. Guarda los tokens en [ApiClient].
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<User> login(String email, String password) =>
      _authenticate('/api/auth/login', {'email': email.trim(), 'password': password});

  Future<User> register(String email, String password, String displayName) => _authenticate('/api/auth/register', {
    'email': email.trim(),
    'password': password,
    'displayName': displayName.trim(),
  });

  /// Recupera la sesión guardada al arrancar. `null` si no hay o ya no vale.
  Future<User?> restore() async {
    if (!await _api.hasStoredSession() || !await _api.refreshSession()) {
      return null;
    }
    return me();
  }

  Future<User> me() async => User.fromJson(await _api.get('/api/users/me') as Json);

  /// Revoca el refresh token en el servidor (si se puede) y borra los tokens locales.
  Future<void> logout() async {
    final refreshToken = await _api.storedRefreshToken();
    try {
      if (refreshToken != null) {
        await _api.post('/api/auth/logout', body: {'refreshToken': refreshToken}, authenticated: false);
      }
    } finally {
      await _api.clearTokens();
    }
  }

  Future<User> _authenticate(String path, Json body) async {
    final json = await _api.post(path, body: body, authenticated: false) as Json;
    await _api.storeTokens(AuthTokens.fromJson(json));
    return User.fromJson(json['user'] as Json);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));
