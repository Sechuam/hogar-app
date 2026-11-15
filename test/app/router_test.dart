import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogar_app/app/router.dart';
import 'package:hogar_app/features/auth/data/auth_repository.dart';

void main() {
  const loading = AsyncLoading<User?>();
  const loggedOut = AsyncData<User?>(null);
  const loggedIn = AsyncData<User?>(User(id: 'u1', email: 'ana@hogar.test', displayName: 'Ana'));

  String? go(AsyncValue<User?> session, String location) => redirectFor(session, Uri.parse(location));

  group('mientras se recupera la sesión', () {
    test('todo va a /splash recordando la ruta pedida', () {
      expect(go(loading, '/households/h1'), '/splash?from=%2Fhouseholds%2Fh1');
      expect(go(loading, '/'), '/splash');
      expect(go(loading, '/splash'), isNull);
    });
  });

  group('sin sesión', () {
    test('todo va a /login, conservando el from que traía el splash', () {
      expect(go(loggedOut, '/splash?from=%2Fhouseholds%2Fh1'), '/login?from=%2Fhouseholds%2Fh1');
      expect(go(loggedOut, '/households/h1'), '/login?from=%2Fhouseholds%2Fh1');
      expect(go(loggedOut, '/login'), isNull);
    });
  });

  group('con sesión', () {
    test('desde splash o login vuelve a la ruta pedida o al inicio', () {
      expect(go(loggedIn, '/splash?from=%2Fhouseholds%2Fh1'), '/households/h1');
      expect(go(loggedIn, '/login?from=%2Fhouseholds%2Fh1%2Fexpenses%2Fnew'), '/households/h1/expenses/new');
      expect(go(loggedIn, '/login'), '/');
    });

    test('las demás rutas no se tocan', () {
      expect(go(loggedIn, '/'), isNull);
      expect(go(loggedIn, '/households/h1'), isNull);
    });

    test('un from que no es una ruta interna se ignora', () {
      for (final from in ['https://evil.test', '//evil.test/x', '/login', '/splash?from=/x']) {
        expect(
          go(loggedIn, Uri(path: '/login', queryParameters: {'from': from}).toString()),
          '/',
          reason: from,
        );
      }
    });
  });
}
