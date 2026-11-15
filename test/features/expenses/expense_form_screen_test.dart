import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hogar_app/core/ui/dates.dart';
import 'package:hogar_app/features/expenses/presentation/expense_form_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_adapter.dart';
import '../../support/fake_api.dart';

void main() {
  const h = 'h1';
  late FakeApi api;

  /// Respuesta de la API al crear: el gasto enviado con su reparto.
  Map<String, Object?> created(Map body, {List<String> warnings = const []}) => {
    ...body,
    'id': 'e1',
    'currency': 'EUR',
    'createdBy': 'ana',
    'splitPolicyApplied': 'EQUAL',
    'shares': [
      {'userId': 'ana', 'amount': '5.00'},
      {'userId': 'luis', 'amount': '5.00'},
    ],
    'warnings': warnings,
  };

  Future<void> pumpForm(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/households/$h/expenses/new',
      routes: [
        GoRoute(
          path: '/households/:id',
          builder: (context, state) => const Scaffold(body: Text('pantalla del hogar')),
          routes: [
            GoRoute(
              path: 'expenses/new',
              builder: (context, state) => ExpenseFormScreen(householdId: h),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: api.overrides,
        retry: (retryCount, error) => null,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    api = FakeApi()
      ..on(
        'GET /api/households/$h',
        (_) => const FakeResponse(200, {
          'id': h,
          'name': 'Piso',
          'splitPolicy': 'EQUAL',
          'plan': 'FREE',
          'currency': 'EUR',
          'myRole': 'OWNER',
          'memberCount': 2,
        }),
      )
      ..on(
        'GET /api/households/$h/members',
        (_) => const FakeResponse(200, [
          {'userId': 'luis', 'displayName': 'Luis', 'email': 'luis@hogar.test', 'role': 'MEMBER'},
          {'userId': 'ana', 'displayName': 'Ana', 'email': 'ana@hogar.test', 'role': 'OWNER'},
        ]),
      );
  });

  testWidgets('no envía importes no válidos ni descripciones vacías', (tester) async {
    await pumpForm(tester);

    for (final amount in ['0', '12,345', '-3', 'doce']) {
      await tester.enterText(find.byKey(const Key('amount')), amount);
      await tester.tap(find.byKey(const Key('save')));
      await tester.pumpAndSettle();
      expect(find.text('Escribe un importe mayor que 0 con 2 decimales como mucho'), findsOneWidget, reason: amount);
    }
    expect(find.text('Describe el gasto'), findsOneWidget);
    expect(api.sent('POST /api/households/$h/expenses'), isEmpty);
  });

  testWidgets('envía el importe como texto exacto, pagado por mí por defecto, y vuelve al hogar', (tester) async {
    api.on('POST /api/households/$h/expenses', (r) => FakeResponse(201, created(r.data as Map)));
    await pumpForm(tester);

    expect(find.text('Ana (yo)'), findsOneWidget, reason: 'quien paga es el usuario actual, no el primero de la lista');
    await tester.enterText(find.byKey(const Key('amount')), '42,5');
    await tester.enterText(find.byKey(const Key('description')), '  Compra semanal ');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    expect(api.sent('POST /api/households/$h/expenses').single.data, {
      'amount': '42.50',
      'description': 'Compra semanal',
      'category': 'GROCERIES',
      'date': Dates.toApi(Dates.today()),
      'paidBy': 'ana',
    });
    expect(find.text('pantalla del hogar'), findsOneWidget);
  });

  testWidgets('avisa si la API repartió a partes iguales por falta de ingresos', (tester) async {
    api.on(
      'POST /api/households/$h/expenses',
      (r) => FakeResponse(201, created(r.data as Map, warnings: ['PROPORTIONAL_FALLBACK_NO_INCOME'])),
    );
    await pumpForm(tester);

    await tester.enterText(find.byKey(const Key('amount')), '10');
    await tester.enterText(find.byKey(const Key('description')), 'Luz');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    expect(find.text('pantalla del hogar'), findsOneWidget);
    expect(find.textContaining('Nadie tenía ingresos ese mes'), findsOneWidget);
  });

  testWidgets('los errores de validación de la API se muestran en su campo', (tester) async {
    api.on(
      'POST /api/households/$h/expenses',
      (_) => FakeResponse(
        400,
        problem(
          'validation-error',
          400,
          errors: [
            {'field': 'date', 'message': 'no puede ser futura'},
          ],
        ),
      ),
    );
    await pumpForm(tester);

    await tester.enterText(find.byKey(const Key('amount')), '10');
    await tester.enterText(find.byKey(const Key('description')), 'Luz');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    expect(find.text('no puede ser futura'), findsOneWidget);
    expect(find.text('pantalla del hogar'), findsNothing);
  });
}
