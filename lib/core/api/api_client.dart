import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../auth/token_store.dart';
import 'api_exception.dart';

typedef Json = Map<String, dynamic>;

/// Tokens que devuelven login, registro y refresh.
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Json json) =>
      AuthTokens(accessToken: json['accessToken'] as String, refreshToken: json['refreshToken'] as String);

  final String accessToken;
  final String refreshToken;
}

/// Único punto que habla HTTP con la API.
///
/// - Añade `Authorization: Bearer` a las peticiones autenticadas.
/// - Ante un 401 renueva el access token **una sola vez** aunque haya varias peticiones a la vez (el
///   refresh token rota y reutilizar uno viejo revoca la sesión, A-004) y reintenta la petición.
/// - Convierte cualquier error en [ApiException].
class ApiClient {
  ApiClient({required String baseUrl, required TokenStore tokenStore, Dio? dio})
    : _tokens = tokenStore,
      _dio =
          dio ??
          Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 20))) {
    _dio.options
      ..baseUrl = baseUrl
      ..contentType = Headers.jsonContentType
      ..responseType = ResponseType.json;
  }

  static const _refreshPath = '/api/auth/refresh';

  final Dio _dio;
  final TokenStore _tokens;
  String? _accessToken;
  Future<AuthTokens?>? _refreshing;

  /// Se llama cuando el refresh token deja de valer (la sesión ha caducado o se revocó).
  void Function()? onSessionExpired;

  /// Se llama con el cuerpo completo de cada login/refresh correcto (incluye `user`).
  void Function(Json authResponse)? onAuthenticated;

  bool get hasAccessToken => _accessToken != null;

  Future<bool> hasStoredSession() async => await _tokens.readRefreshToken() != null;

  /// Guarda los tokens de una respuesta de login/registro/refresh.
  Future<void> storeTokens(AuthTokens tokens) async {
    _accessToken = tokens.accessToken;
    await _tokens.writeRefreshToken(tokens.refreshToken);
  }

  Future<String?> storedRefreshToken() => _tokens.readRefreshToken();

  Future<void> clearTokens() async {
    _accessToken = null;
    await _tokens.clear();
  }

  /// Renueva la sesión con el refresh token guardado. `false` si no hay sesión o ya no vale.
  Future<bool> refreshSession() async => await _refreshOnce() != null;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) => _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body, bool authenticated = true}) =>
      _send('POST', path, body: body, authenticated: authenticated);

  Future<dynamic> put(String path, {Object? body}) => _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) => _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// `multipart/form-data`. El formulario se construye en cada intento: un [FormData] ya enviado no
  /// se puede reenviar si hay que repetir la petición tras renovar el token.
  Future<dynamic> upload(String path, FormData Function() form) => _send('POST', path, body: form);

  /// Contenido binario (p. ej. una factura).
  Future<Uint8List> getBytes(String path) async =>
      Uint8List.fromList(await _send('GET', path, responseType: ResponseType.bytes) as List<int>);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    ResponseType? responseType,
  }) async {
    if (authenticated && _accessToken == null) {
      await _refreshOrExpire();
    }
    try {
      return await _request(method, path, body, query, authenticated, responseType);
    } on DioException catch (e) {
      if (authenticated && e.response?.statusCode == 401) {
        await _refreshOrExpire();
        try {
          return await _request(method, path, body, query, authenticated, responseType);
        } on DioException catch (retry) {
          throw ApiException.fromDio(retry);
        }
      }
      throw ApiException.fromDio(e);
    }
  }

  Future<dynamic> _request(
    String method,
    String path,
    Object? body,
    Map<String, dynamic>? query,
    bool authenticated,
    ResponseType? responseType,
  ) async {
    final data = body is FormData Function() ? body() : body;
    final response = await _dio.request<dynamic>(
      path,
      data: data,
      queryParameters: query?..removeWhere((_, value) => value == null),
      options: Options(
        method: method,
        headers: authenticated ? {'Authorization': 'Bearer $_accessToken'} : null,
        responseType: responseType,
        contentType: data is FormData ? Headers.multipartFormDataContentType : null,
      ),
    );
    return response.data;
  }

  Future<void> _refreshOrExpire() async {
    if (await _refreshOnce() == null) {
      onSessionExpired?.call();
      throw const ApiException(
        code: ApiException.sessionExpired,
        message: 'Tu sesión ha caducado. Vuelve a iniciar sesión.',
        status: 401,
      );
    }
  }

  /// Comparte el refresh en vuelo entre todas las peticiones que lo necesiten a la vez.
  Future<AuthTokens?> _refreshOnce() {
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<AuthTokens?> _refresh() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null) {
      _accessToken = null;
      return null;
    }
    try {
      final response = await _dio.post<dynamic>(_refreshPath, data: {'refreshToken': refreshToken});
      final json = response.data as Json;
      final tokens = AuthTokens.fromJson(json);
      await storeTokens(tokens);
      onAuthenticated?.call(json);
      return tokens;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 400) {
        await clearTokens();
        return null;
      }
      // Sin red o error del servidor: la sesión puede seguir siendo válida, no se borra.
      throw ApiException.fromDio(e);
    }
  }
}
