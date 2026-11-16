import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogar_app/features/incomes/data/incomes_repository.dart';
import 'package:hogar_app/features/incomes/presentation/incomes_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_adapter.dart';
import '../../support/fake_api.dart';

void main() {
  const h = 'h1';
  const path = '/api/households/$h/incomes';
  late FakeApi api;
  late List<Map<String, Object?>> myIncomes;

  Map<String, Object?> household(String policy) => {
    'id': h,
    'name': 'Piso',
    'splitPolicy': policy,
    'plan': 'FREE',
    'currency': 'EUR',
    'myRole': 'OWNER',
    'memberCount': 2,
  };

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: api.overrides,
        retry: (retryCount, error) => null,
        child: MaterialApp(
          home: IncomesScreen(householdId: h, initialMonth: DateTime(2026, 11)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// El botón queda bajo el formulario: se desplaza a la vista antes de pulsarlo.
  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('incomeSave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('incomeSave')));
  }

  setUp(() {
    myIncomes = [
      {
        'id': 'i1',
        'userId': 'ana',
        'amount': 1800.0,
        'currency': 'EUR',
        'concept': 'Nómina',
        'date': '2026-01-01',
        'recurring': true,
        'endDate': null,
        'createdAt': '2026-01-01T10:00:00Z',
      },
    ];
    api = FakeApi()
      ..on('GET /api/households/$h', (_) => FakeResponse(200, household('PROPORTIONAL')))
      ..on(
        'GET /api/households/$h/members',
        (_) => const FakeResponse(200, [
          {'userId': 'ana', 'displayName': 'Ana', 'email': 'ana@hogar.test', 'role': 'OWNER'},
          {'userId': 'luis', 'displayName': 'Luis', 'email': 'luis@hogar.test', 'role': 'MEMBER'},
        ]),
      )
      ..on('GET $path/summary', (r) {
        final november = r.queryParameters['month'] == '2026-11';
        return FakeResponse(200, {
          'month': r.queryParameters['month'],
          'currency': 'EUR',
          'total': november ? '3000.00' : '0.00',
          'members': [
            {'userId': 'ana', 'amount': november ? '1800.00' : '0.00', 'percentage': november ? '60.00' : '0.00'},
            {'userId': 'luis', 'amount': november ? '1200.00' : '0.00', 'percentage': november ? '40.00' : '0.00'},
          ],
        });
      })
      ..on('GET $path', (_) => FakeResponse(200, {'content': myIncomes, 'page': 0, 'totalPages': 1}));
  });

  testWidgets('muestra el reparto del mes y cambia de mes', (tester) async {
    await pumpScreen(tester);

    expect(find.text('noviembre de 2026'), findsOneWidget);
    expect(find.text('3.000,00 €'), findsOneWidget);
    expect(find.text('1.800,00 € · 60 %'), findsOneWidget);
    expect(find.text('1.200,00 € · 40 %'), findsOneWidget);
    expect(find.text('Luis'), findsOneWidget);
    // Solo se piden los ingresos propios.
    expect(api.sent('GET $path').single.queryParameters['userId'], 'ana');
    expect(find.text('Nómina'), findsOneWidget);
    expect(find.text('cada mes desde el 01/01/2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Mes siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('diciembre de 2026'), findsOneWidget);
    expect(api.sent('GET $path/summary').last.queryParameters['month'], '2026-12');
    expect(find.textContaining('Nadie tiene ingresos este mes'), findsOneWidget);
  });

  testWidgets('avisa si el hogar reparte a partes iguales', (tester) async {
    api.on('GET /api/households/$h', (_) => FakeResponse(200, household('EQUAL')));
    await pumpScreen(tester);

    expect(find.text('Este hogar reparte a partes iguales'), findsOneWidget);
  });

  testWidgets('crea un ingreso recurrente y recarga resumen y lista', (tester) async {
    api.on('POST $path', (r) {
      final body = r.data as Map<String, Object?>;
      final created = {
        ...body,
        'id': 'i2',
        'userId': 'ana',
        'currency': 'EUR',
        'endDate': null,
        'createdAt': '2026-11-15T10:00:00Z',
      };
      myIncomes = [...myIncomes, created];
      return FakeResponse(201, created);
    });
    await pumpScreen(tester);
    final summariesBefore = api.sent('GET $path/summary').length;

    await tester.tap(find.text('Ingreso'));
    await tester.pumpAndSettle();
    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(find.text('Escribe el concepto (p. ej. Nómina)'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('incomeConcept')), ' Clases particulares ');
    await tester.enterText(find.byKey(const Key('incomeAmount')), '250,5');
    await tapSave(tester);
    await tester.pumpAndSettle();

    final body = api.sent('POST $path').single.data as Map;
    expect(body['amount'], '250.50');
    expect(body['concept'], 'Clases particulares');
    expect(body['recurring'], isTrue);
    expect(body.containsKey('endDate'), isFalse);
    expect(find.text('Clases particulares'), findsOneWidget);
    expect(api.sent('GET $path/summary').length, greaterThan(summariesBefore));
  });

  testWidgets('los errores de validación de la API se muestran en el formulario', (tester) async {
    api.on(
      'PUT $path/i1',
      (_) => FakeResponse(
        400,
        problem(
          'validation-error',
          400,
          errors: [
            {'field': 'endDateValid', 'message': 'endDate no puede ser anterior a date'},
          ],
        ),
      ),
    );
    await pumpScreen(tester);

    await tester.tap(find.text('Nómina'));
    await tester.pumpAndSettle();
    expect(find.text('Editar ingreso'), findsOneWidget);
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(api.sent('PUT $path/i1').single.data, {
      'amount': '1800.00',
      'concept': 'Nómina',
      'date': '2026-01-01',
      'recurring': true,
    });
    expect(find.text('endDate no puede ser anterior a date'), findsOneWidget);
    expect(find.text('Editar ingreso'), findsOneWidget, reason: 'el formulario sigue abierto');
  });

  testWidgets('borrar pide confirmación', (tester) async {
    api.on('DELETE $path/i1', (_) {
      myIncomes = [];
      return const FakeResponse(204);
    });
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Borrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(api.sent('DELETE $path/i1'), isEmpty);

    await tester.tap(find.byTooltip('Borrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Borrar')));
    await tester.pumpAndSettle();

    expect(api.sent('DELETE $path/i1'), hasLength(1));
    expect(find.textContaining('Aún no has apuntado ingresos'), findsOneWidget);
  });

  testWidgets('el formulario cabe en una pantalla baja (hace scroll en vez de desbordarse)', (tester) async {
    tester.view.physicalSize = const Size(360, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpScreen(tester);

    await tester.tap(find.text('Ingreso'));
    await tester.pumpAndSettle();

    // Un desbordamiento de layout se notifica como excepción y haría fallar el test.
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('incomeSave')),
      100,
      scrollable: find.descendant(of: find.byType(IncomeForm), matching: find.byType(Scrollable)).first,
    );
    expect(find.byKey(const Key('incomeSave')).hitTestable(), findsOneWidget);
  });

  test('un ingreso puntual nunca envía fecha de fin', () {
    final json = NewIncome(
      amount: Decimal.parse('10'),
      concept: 'Regalo',
      date: DateTime(2026, 11, 3),
      recurring: false,
      endDate: DateTime(2026, 12, 31),
    ).toJson();

    expect(json, {'amount': '10.00', 'concept': 'Regalo', 'date': '2026-11-03', 'recurring': false});
  });
}
