import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogar_app/features/auth/presentation/login_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_adapter.dart';
import '../../support/fake_api.dart';

void main() {
  late FakeApi api;

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: api.overrides,
        retry: (retryCount, error) => null,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => api = FakeApi(loggedIn: false));

  testWidgets('valida los campos antes de llamar a la API', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();

    expect(find.text('Escribe un email válido'), findsOneWidget);
    expect(find.text('Escribe tu contraseña'), findsOneWidget);
    expect(api.sent('POST /api/auth/login'), isEmpty);
  });

  testWidgets('el registro exige nombre y contraseña de 8 caracteres', (tester) async {
    await pumpLogin(tester);
    await tester.tap(find.text('Crear una cuenta nueva'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('email')), 'ana@hogar.test');
    await tester.enterText(find.byKey(const Key('password')), 'corta');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();

    expect(find.text('Escribe tu nombre'), findsOneWidget);
    // El error sustituye al texto de ayuda con el mismo mensaje.
    expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
    expect(api.sent('POST /api/auth/register'), isEmpty);
  });

  testWidgets('los errores por campo de la API se muestran en su campo', (tester) async {
    api.on(
      'POST /api/auth/register',
      (_) => FakeResponse(
        400,
        problem(
          'validation-error',
          400,
          errors: [
            {'field': 'email', 'message': 'Ya hay una cuenta con ese email'},
          ],
        ),
      ),
    );
    await pumpLogin(tester);
    await tester.tap(find.text('Crear una cuenta nueva'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('name')), 'Ana');
    await tester.enterText(find.byKey(const Key('email')), 'ana@hogar.test');
    await tester.enterText(find.byKey(const Key('password')), 'contraseña-larga');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();

    expect(find.text('Ya hay una cuenta con ese email'), findsOneWidget);
    expect(find.byKey(const Key('error')), findsNothing);
    expect(api.sent('POST /api/auth/register').single.data, {
      'email': 'ana@hogar.test',
      'password': 'contraseña-larga',
      'displayName': 'Ana',
    });
  });

  testWidgets('credenciales incorrectas muestran el mensaje de la API', (tester) async {
    api.on(
      'POST /api/auth/login',
      (_) => FakeResponse(401, problem('invalid-credentials', 401, detail: 'Email o contraseña incorrectos.')),
    );
    await pumpLogin(tester);

    await tester.enterText(find.byKey(const Key('email')), ' ana@hogar.test ');
    await tester.enterText(find.byKey(const Key('password')), 'mala');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();

    expect(find.text('Email o contraseña incorrectos.'), findsOneWidget);
    expect((api.sent('POST /api/auth/login').single.data as Map)['email'], 'ana@hogar.test');
  });
}
