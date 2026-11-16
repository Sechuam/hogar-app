import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogar_app/core/ui/dates.dart';
import 'package:hogar_app/features/expenses/presentation/expenses_tab.dart';
import 'package:hogar_app/features/invoices/data/invoice_files.dart';
import 'package:hogar_app/features/invoices/data/invoices_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_adapter.dart';
import '../../support/fake_api.dart';

class _PickTicket implements InvoiceFiles {
  @override
  Future<InvoiceFile?> pick() async => InvoiceFile(name: 'ticket.pdf', bytes: Uint8List.fromList([37, 80, 68, 70]));

  @override
  Future<void> open(Uint8List bytes, {required String filename, required String contentType}) async {}
}

void main() {
  const h = 'h1';
  late FakeApi api;
  late Set<String> withInvoice;

  Map<String, Object?> expense(String id, String description) => {
    'id': id,
    'amount': '20.00',
    'currency': 'EUR',
    'description': description,
    'category': 'GROCERIES',
    'date': Dates.toApi(Dates.today()),
    'paidBy': 'ana',
    'createdBy': 'ana',
    'splitPolicyApplied': 'EQUAL',
    'shares': [
      {'userId': 'ana', 'amount': '20.00', 'weight': '1.00'},
    ],
    'warnings': <String>[],
    'hasInvoice': withInvoice.contains(id),
  };

  Future<void> pumpTab(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...api.overrides, invoiceFilesProvider.overrideWithValue(_PickTicket())],
        retry: (retryCount, error) => null,
        child: const MaterialApp(
          home: Scaffold(body: ExpensesTab(householdId: h)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    withInvoice = {'e1'};
    api = FakeApi()
      ..on(
        'GET /api/households/$h',
        (_) => const FakeResponse(200, {
          'id': h,
          'name': 'Piso',
          'splitPolicy': 'EQUAL',
          'plan': 'PREMIUM',
          'currency': 'EUR',
          'myRole': 'OWNER',
          'memberCount': 1,
        }),
      )
      ..on(
        'GET /api/households/$h/members',
        (_) => const FakeResponse(200, [
          {'userId': 'ana', 'displayName': 'Ana', 'email': 'ana@hogar.test', 'role': 'OWNER'},
        ]),
      )
      ..on('GET /api/households/$h/plan', (_) => const FakeResponse(200, {}))
      ..on(
        'GET /api/households/$h/expenses',
        (_) => FakeResponse(200, {
          'content': [expense('e1', 'Luz'), expense('e2', 'Compra')],
          'page': 0,
          'totalPages': 1,
        }),
      )
      ..on(
        'GET /api/households/$h/expenses/e2/invoice/metadata',
        (_) => FakeResponse(404, problem('invoice-not-found', 404)),
      )
      ..on('POST /api/households/$h/expenses/e2/invoice', (_) {
        withInvoice.add('e2');
        return const FakeResponse(201, {
          'id': 'inv2',
          'expenseId': 'e2',
          'contentType': 'application/pdf',
          'sizeBytes': 4,
          'filename': 'ticket.pdf',
          'sha256': 'abc',
          'uploadedBy': 'ana',
          'createdAt': '2026-11-16T10:00:00Z',
        });
      });
  });

  Finder iconIn(String description) => find.descendant(
    of: find.ancestor(of: find.text(description), matching: find.byType(ListTile)),
    matching: find.byKey(const Key('hasInvoice')),
  );

  testWidgets('marca con un icono solo los gastos que tienen factura', (tester) async {
    await pumpTab(tester);

    expect(iconIn('Luz'), findsOneWidget);
    expect(iconIn('Compra'), findsNothing);
  });

  testWidgets('al adjuntar una factura desde la ficha, el icono aparece en la lista', (tester) async {
    await pumpTab(tester);
    final listsBefore = api.sent('GET /api/households/$h/expenses').length;

    await tester.tap(find.text('Compra'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('invoiceAttach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invoiceAttach')));
    await tester.pumpAndSettle();
    // Cierra la ficha.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(api.sent('GET /api/households/$h/expenses').length, greaterThan(listsBefore));
    expect(iconIn('Compra'), findsOneWidget);
  });
}
