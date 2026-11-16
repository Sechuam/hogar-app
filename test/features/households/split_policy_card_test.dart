import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogar_app/features/households/data/households_repository.dart';
import 'package:hogar_app/features/households/presentation/household_info_tab.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_adapter.dart';
import '../../support/fake_api.dart';

void main() {
  const h = 'h1';
  late FakeApi api;

  Household household({String role = 'OWNER'}) =>
      Household(id: h, name: 'Piso', splitPolicy: 'EQUAL', plan: 'FREE', currency: 'EUR', myRole: role, memberCount: 2);

  Future<void> pumpCard(WidgetTester tester, Household value) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: api.overrides,
        retry: (retryCount, error) => null,
        child: MaterialApp(
          home: Scaffold(body: SplitPolicyCard(household: value)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => api = FakeApi());

  testWidgets('el propietario cambia a reparto proporcional tras confirmar', (tester) async {
    api.on(
      'PATCH /api/households/$h',
      (r) => const FakeResponse(200, {
        'id': h,
        'name': 'Piso',
        'splitPolicy': 'PROPORTIONAL',
        'plan': 'FREE',
        'currency': 'EUR',
        'myRole': 'OWNER',
        'memberCount': 2,
      }),
    );
    await pumpCard(tester, household());

    await tester.tap(find.text('Según ingresos'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Los gastos ya creados conservan su reparto'), findsOneWidget);
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();

    expect(api.sent('PATCH /api/households/$h').single.data, {'splitPolicy': 'PROPORTIONAL'});
  });

  testWidgets('un miembro ve la política pero no puede cambiarla', (tester) async {
    await pumpCard(tester, household(role: 'MEMBER'));

    expect(find.textContaining('Solo el propietario puede cambiarlo'), findsOneWidget);
    await tester.tap(find.text('Según ingresos'));
    await tester.pumpAndSettle();
    expect(find.text('Cambiar'), findsNothing);
    expect(api.sent('PATCH /api/households/$h'), isEmpty);
  });
}
