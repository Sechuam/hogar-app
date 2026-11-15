import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogar_app/core/api/api_client.dart';
import 'package:hogar_app/core/api/api_exception.dart';
import 'package:hogar_app/core/auth/token_store.dart';

import '../../support/fake_adapter.dart';

void main() {
  late MemoryTokenStore store;
  late FakeAdapter adapter;
  late ApiClient client;
  var refreshCalls = 0;
  var validAccess = 'access-1';

  Map<String, Object?> auth(String access, String refresh) => {
    'accessToken': access,
    'refreshToken': refresh,
    'tokenType': 'Bearer',
    'expiresIn': 900,
    'user': {'id': 'u1', 'email': 'ana@hogar.test', 'displayName': 'Ana'},
  };

  ApiClient build(FakeHandler handler) {
    adapter = FakeAdapter(handler);
    final dio = Dio()..httpClientAdapter = adapter;
    return ApiClient(baseUrl: 'http://api.test', tokenStore: store, dio: dio);
  }

  /// API que acepta solo [validAccess] y rota el refresh token en cada uso.
  Future<FakeResponse> api(RequestOptions r) async {
    if (r.path == '/api/auth/refresh') {
      refreshCalls++;
      final sent = (r.data as Map)['refreshToken'];
      if (sent != 'refresh-$refreshCalls') {
        return FakeResponse(401, problem('invalid-refresh-token', 401));
      }
      // Simula latencia para que las peticiones concurrentes coincidan.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      validAccess = 'access-${refreshCalls + 1}';
      return FakeResponse(200, auth(validAccess, 'refresh-${refreshCalls + 1}'));
    }
    if (r.headers['Authorization'] != 'Bearer $validAccess') {
      return FakeResponse(401, problem('unauthorized', 401));
    }
    return FakeResponse(200, {'path': r.path});
  }

  setUp(() {
    store = MemoryTokenStore('refresh-1');
    refreshCalls = 0;
    validAccess = 'access-1';
  });

  test('sin access token en memoria, renueva la sesión antes de la primera petición', () async {
    client = build(api);

    expect(await client.get('/api/users/me'), {'path': '/api/users/me'});
    expect(refreshCalls, 1);
    expect(await store.readRefreshToken(), 'refresh-2');
  });

  test('varios 401 a la vez comparten un único refresh y todos se reintentan', () async {
    client = build(api);
    await client.storeTokens(const AuthTokens(accessToken: 'caducado', refreshToken: 'refresh-1'));

    final results = await Future.wait([for (var i = 0; i < 5; i++) client.get('/api/households/$i')]);

    expect(refreshCalls, 1, reason: 'reutilizar el refresh token rotado revocaría la sesión');
    expect(results.map((r) => (r as Map)['path']), [for (var i = 0; i < 5; i++) '/api/households/$i']);
  });

  test('si el refresh token ya no vale, avisa de sesión caducada y borra los tokens', () async {
    store = MemoryTokenStore('revocado');
    client = build(api);
    var expired = 0;
    client.onSessionExpired = () => expired++;

    await expectLater(
      client.get('/api/households'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiException.sessionExpired)),
    );
    expect(expired, 1);
    expect(await store.readRefreshToken(), isNull);
  });

  test('un fallo de red al renovar no borra la sesión guardada', () async {
    client = build((r) async => throw DioException.connectionError(requestOptions: r, reason: 'sin red'));

    await expectLater(
      client.get('/api/households'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiException.network)),
    );
    expect(await store.readRefreshToken(), 'refresh-1');
  });

  test('las peticiones sin autenticar no llevan token ni disparan refresh', () async {
    client = build(
      (r) async => FakeResponse(401, problem('invalid-credentials', 401, detail: 'Email o contraseña incorrectos.')),
    );

    await expectLater(
      client.post('/api/auth/login', body: {'email': 'a', 'password': 'b'}, authenticated: false),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'invalid-credentials')
            .having((e) => e.message, 'message', 'Email o contraseña incorrectos.'),
      ),
    );
    expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('un ProblemDetail de validación conserva los errores por campo y Retry-After', () async {
    client = build(
      (r) async => FakeResponse(
        r.path.endsWith('limited') ? 429 : 400,
        problem(
          r.path.endsWith('limited') ? 'rate-limited' : 'validation-error',
          400,
          errors: [
            {'field': 'amount', 'message': 'debe ser mayor que 0'},
            {'field': 'amount', 'message': 'segundo mensaje ignorado'},
          ],
        ),
        {
          'retry-after': ['42'],
        },
      ),
    );
    await client.storeTokens(const AuthTokens(accessToken: 'a', refreshToken: 'r'));

    final validation = await client
        .post('/api/x')
        .then<ApiException?>((_) => null, onError: (Object e) => e as ApiException);
    expect(validation!.fieldErrors, {'amount': 'debe ser mayor que 0'});
    expect(validation.requestId, 'req-1');

    final limited = await client
        .get('/api/limited')
        .then<ApiException?>((_) => null, onError: (Object e) => e as ApiException);
    expect(limited!.code, 'rate-limited');
    expect(limited.retryAfterSeconds, 42);
  });

  test('una respuesta de error que no es ProblemDetail se trata como error inesperado', () async {
    client = build((r) async => const FakeResponse(502, 'Bad gateway'));
    await client.storeTokens(const AuthTokens(accessToken: 'a', refreshToken: 'r'));

    await expectLater(
      client.get('/api/households'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 502)),
    );
  });

  test('los parámetros nulos no se envían en la query', () async {
    client = build((r) async => const FakeResponse(200, {}));
    await client.storeTokens(const AuthTokens(accessToken: 'a', refreshToken: 'r'));

    await client.get('/api/households/h/tasks', query: {'status': 'PENDING', 'assigneeId': null});

    expect(adapter.requests.single.queryParameters, {'status': 'PENDING'});
  });
}
