import 'package:dio/dio.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:hogar_app/core/api/api_client.dart';
import 'package:hogar_app/core/auth/token_store.dart';
import 'package:hogar_app/core/providers.dart';

import 'fake_adapter.dart';

/// API falsa para tests de widgets: rutas `'MÉTODO /path'` → respuesta. Solo se sustituye el
/// [ApiClient], así que pantallas, providers y repositorios son los reales.
class FakeApi {
  FakeApi({bool loggedIn = true}) : _store = MemoryTokenStore(loggedIn ? 'refresh-1' : null) {
    if (loggedIn) {
      on(
        'POST /api/auth/refresh',
        (_) => FakeResponse(200, {
          'accessToken': 'access',
          'refreshToken': 'refresh-2',
          'tokenType': 'Bearer',
          'expiresIn': 900,
          'user': me,
        }),
      );
      on('GET /api/users/me', (_) => FakeResponse(200, me));
    }
  }

  static const me = {'id': 'ana', 'email': 'ana@hogar.test', 'displayName': 'Ana'};

  final MemoryTokenStore _store;
  final _routes = <String, FakeResponse Function(RequestOptions)>{};
  late final adapter = FakeAdapter((r) async {
    final route = _routes['${r.method} ${r.path}'];
    return route == null ? FakeResponse(404, problem('not-found', 404)) : route(r);
  });

  void on(String route, FakeResponse Function(RequestOptions request) respond) => _routes[route] = respond;

  /// Peticiones enviadas a [route] (`'MÉTODO /path'`).
  List<RequestOptions> sent(String route) => adapter.requests.where((r) => '${r.method} ${r.path}' == route).toList();

  List<Override> get overrides => [
    apiClientProvider.overrideWithValue(
      ApiClient(baseUrl: 'http://api.test', tokenStore: _store, dio: Dio()..httpClientAdapter = adapter),
    ),
  ];
}
