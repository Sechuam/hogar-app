import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogar_app/core/ui/dates.dart';
import 'package:hogar_app/features/balances/presentation/balances_tab.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_adapter.dart';
import '../../support/fake_api.dart';

void main() {
  const h = 'h1';
  late FakeApi api;
  var settled = false;

  Future<void> pumpTab(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: api.overrides,
        retry: (retryCount, error) => null,
        child: const MaterialApp(
          home: Scaffold(body: BalancesTab(householdId: h)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    settled = false;
    api = FakeApi()
      ..on(
        'GET /api/households/$h/members',
        (_) => const FakeResponse(200, [
          {'userId': 'ana', 'displayName': 'Ana', 'email': 'ana@hogar.test', 'role': 'OWNER'},
        ]),
      )
      ..on(
        'GET /api/households/$h/balances',
        (_) => FakeResponse(200, {
          'currency': 'EUR',
          'settled': settled,
          'members': [
            {'userId': 'ana', 'active': true, 'balance': settled ? '0.00' : '22.75'},
            // Se fue del hogar con una deuda pendiente: sigue contando.
            {'userId': 'eva', 'active': false, 'balance': settled ? '0.00' : '-22.75'},
          ],
        }),
      )
      ..on(
        'GET /api/households/$h/settlements/suggested',
        (_) => FakeResponse(200, {
          'transfers': [
            if (!settled) {'fromUserId': 'eva', 'toUserId': 'ana', 'amount': '22.75'},
          ],
        }),
      )
      ..on('POST /api/households/$h/settlements', (_) {
        settled = true;
        return const FakeResponse(201, {});
      });
  });

  testWidgets('muestra saldos y el pago sugerido, también de quien ya no es miembro', (tester) async {
    await pumpTab(tester);

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('22,75 €'), findsWidgets);
    expect(find.text('Ex-miembro'), findsOneWidget);
    expect(find.text('-22,75 €'), findsOneWidget);
    expect(find.text('Ex-miembro paga a Ana'), findsOneWidget);
  });

  testWidgets('Registrar pide confirmación, anota el pago y recarga los saldos', (tester) async {
    await pumpTab(tester);

    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.textContaining('La app no mueve dinero')),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(api.sent('POST /api/households/$h/settlements'), isEmpty);

    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Registrar')));
    await tester.pumpAndSettle();

    expect(api.sent('POST /api/households/$h/settlements').single.data, {
      'fromUserId': 'eva',
      'toUserId': 'ana',
      'amount': '22.75',
      'date': Dates.toApi(Dates.today()),
    });
    expect(find.text('Todo está saldado.'), findsOneWidget);
  });

  testWidgets('un miembro activo que falta en la caché recarga la lista de miembros una vez', (tester) async {
    var membersCalls = 0;
    api.on('GET /api/households/$h/members', (_) {
      membersCalls++;
      return FakeResponse(200, [
        {'userId': 'ana', 'displayName': 'Ana', 'email': 'ana@hogar.test', 'role': 'OWNER'},
        if (membersCalls > 1) {'userId': 'luis', 'displayName': 'Luis', 'email': 'luis@hogar.test', 'role': 'MEMBER'},
      ]);
    });
    api.on(
      'GET /api/households/$h/balances',
      (_) => const FakeResponse(200, {
        'currency': 'EUR',
        'settled': true,
        'members': [
          {'userId': 'ana', 'active': true, 'balance': '0.00'},
          {'userId': 'luis', 'active': true, 'balance': '0.00'},
        ],
      }),
    );
    await pumpTab(tester);

    expect(find.text('Luis'), findsOneWidget);
    expect(membersCalls, 2);
  });
}
