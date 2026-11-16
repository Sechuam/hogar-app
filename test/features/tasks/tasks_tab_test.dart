import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogar_app/core/ui/dates.dart';
import 'package:hogar_app/features/tasks/presentation/tasks_tab.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_adapter.dart';
import '../../support/fake_api.dart';

void main() {
  const h = 'h1';
  const path = '/api/households/$h/tasks';
  late FakeApi api;
  late List<Map<String, Object?>> pending;
  final today = Dates.today();

  Map<String, Object?> task(
    String id,
    String title, {
    String recurrence = 'NONE',
    DateTime? due,
    bool overdue = false,
  }) => {
    'id': id,
    'title': title,
    'assigneeId': null,
    'recurrence': recurrence,
    'dueDate': due == null ? null : Dates.toApi(due),
    'status': 'PENDING',
    'overdue': overdue,
  };

  Future<void> pumpTab(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: api.overrides,
        retry: (retryCount, error) => null,
        child: const MaterialApp(
          home: Scaffold(body: TasksTab(householdId: h)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Marca una tarea y espera a que termine todo: la animación de "hecha" y, al acabar esta, la
  /// llamada a la API (que empieza después del último fotograma, así que hay que dejar correr el tiempo).
  Future<void> check(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
  }

  setUp(() {
    pending = [
      task('t1', 'Sacar la basura', recurrence: 'WEEKLY', due: today.subtract(const Duration(days: 2)), overdue: true),
      task('t2', 'Comprar bombillas', due: today),
      task('t3', 'Regar', recurrence: 'DAILY', due: today.add(const Duration(days: 1))),
    ];
    api = FakeApi()
      ..on('GET /api/households/$h/members', (_) => const FakeResponse(200, []))
      ..on('GET $path', (_) => FakeResponse(200, {'content': pending, 'page': 0, 'totalPages': 1}));
  });

  testWidgets('el resumen cuenta vencidas, de hoy y las de más adelante', (tester) async {
    await pumpTab(tester);

    String stat(String label) => (tester.widget<Text>(
      find
          .descendant(
            of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
            matching: find.byType(Text),
          )
          .first,
    )).data!;
    expect(stat('Vencidas'), '1');
    expect(stat('Para hoy'), '1');
    expect(stat('Más adelante'), '1');
  });

  testWidgets('completar una tarea puntual ofrece deshacer, que la reabre', (tester) async {
    api
      ..on('POST $path/t2/complete', (_) {
        pending = pending.where((t) => t['id'] != 't2').toList();
        return const FakeResponse(200, {});
      })
      ..on('POST $path/t2/reopen', (_) {
        pending = [...pending, task('t2', 'Comprar bombillas', due: today)];
        return const FakeResponse(200, {});
      });
    await pumpTab(tester);

    await check(tester, 'Comprar bombillas');

    expect(api.sent('POST $path/t2/complete').single.data, {'dueDate': Dates.toApi(today)});
    expect(find.text('Comprar bombillas'), findsNothing);
    expect(find.text('"Comprar bombillas" hecha'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(api.sent('POST $path/t2/reopen'), hasLength(1));
    expect(find.text('Comprar bombillas'), findsOneWidget);
  });

  testWidgets('una periódica no ofrece deshacer y su siguiente repetición se ve pendiente', (tester) async {
    // Como en el navegador: la única tarea pasa de "Para hoy" a "Próximas" y ocupa el mismo sitio en
    // pantalla, así que Flutter reutiliza su estado.
    pending = [task('t1', 'Limpiar el baño', recurrence: 'WEEKLY', due: today)];
    api.on('POST $path/t1/complete', (_) {
      // La API reutiliza la tarea: mismo id, fecha siguiente.
      pending = [task('t1', 'Limpiar el baño', recurrence: 'WEEKLY', due: today.add(const Duration(days: 7)))];
      return const FakeResponse(200, {});
    });
    await pumpTab(tester);

    await check(tester, 'Limpiar el baño');

    expect(find.text('"Limpiar el baño" hecha; se repetirá'), findsOneWidget);
    expect(find.text('Deshacer'), findsNothing);
    expect(find.text('Próximas · 1'), findsOneWidget);
    // Antes quedaba invisible: la animación de "hecha" seguía aplicada a la nueva repetición.
    final tile = find.ancestor(of: find.text('Limpiar el baño'), matching: find.byType(Opacity)).first;
    expect(tester.widget<Opacity>(tile).opacity, 1);
    expect(tester.widget<Checkbox>(find.descendant(of: tile, matching: find.byType(Checkbox))).value, isFalse);
  });

  testWidgets('si otra persona ya la completó (409), avisa y recarga', (tester) async {
    api.on(
      'POST $path/t2/complete',
      (_) => FakeResponse(409, problem('task-already-done', 409, detail: 'Otra persona ya la completó.')),
    );
    await pumpTab(tester);
    final loadsBefore = api.sent('GET $path').length;

    await check(tester, 'Comprar bombillas');

    expect(find.text('Otra persona ya la completó.'), findsOneWidget);
    expect(api.sent('GET $path').length, greaterThan(loadsBefore));
  });
}
