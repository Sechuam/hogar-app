import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogar_app/core/ui/widgets.dart';
import 'package:hogar_app/features/invoices/data/invoice_files.dart';
import 'package:hogar_app/features/invoices/data/invoices_repository.dart';
import 'package:hogar_app/features/invoices/presentation/invoice_section.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_adapter.dart';
import '../../support/fake_api.dart';

class FakeFiles implements InvoiceFiles {
  InvoiceFile? next;
  final opened = <(Uint8List, String, String)>[];

  @override
  Future<InvoiceFile?> pick() async => next;

  @override
  Future<void> open(Uint8List bytes, {required String filename, required String contentType}) async =>
      opened.add((bytes, filename, contentType));
}

void main() {
  const h = 'h1';
  const e = 'e1';
  const path = '/api/households/$h/expenses/$e/invoice';
  late FakeApi api;
  late FakeFiles files;
  Map<String, Object?>? stored;

  Map<String, Object?> metadata(String filename, String type, int size) => {
    'id': 'inv1',
    'expenseId': e,
    'contentType': type,
    'sizeBytes': size,
    'filename': filename,
    'sha256': 'abc',
    'uploadedBy': 'ana',
    'createdAt': '2026-11-14T10:00:00Z',
  };

  Future<void> pump(WidgetTester tester, {bool canEdit = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...api.overrides, invoiceFilesProvider.overrideWithValue(files)],
        retry: (retryCount, error) => null,
        child: MaterialApp(
          home: Scaffold(
            body: InvoiceSection(householdId: h, expenseId: e, canEdit: canEdit),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    stored = null;
    files = FakeFiles();
    api = FakeApi()
      ..on(
        'GET $path/metadata',
        (_) => stored == null ? FakeResponse(404, problem('invoice-not-found', 404)) : FakeResponse(200, stored),
      )
      ..on('GET /api/households/$h/plan', (_) => const FakeResponse(200, {}));
  });

  testWidgets('adjunta una factura y la muestra con tipo y tamaño', (tester) async {
    api.on('POST $path', (r) {
      final file = (r.data as FormData).files.single;
      stored = metadata(file.value.filename!, 'application/pdf', 188416);
      return FakeResponse(201, stored);
    });
    files.next = InvoiceFile(name: 'ticket.pdf', bytes: Uint8List.fromList([37, 80, 68, 70]));
    await pump(tester);

    await tester.tap(find.byKey(const Key('invoiceAttach')));
    await tester.pumpAndSettle();

    final form = api.sent('POST $path').single.data as FormData;
    expect(form.files.single.key, 'file');
    expect(find.text('ticket.pdf'), findsOneWidget);
    expect(find.textContaining('PDF · 184 KB'), findsOneWidget);
    expect(find.byKey(const Key('invoiceAttach')), findsNothing);
  });

  testWidgets('cancelar la selección no envía nada', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('invoiceAttach')));
    await tester.pumpAndSettle();

    expect(api.sent('POST $path'), isEmpty);
    expect(find.byKey(const Key('invoiceError')), findsNothing);
  });

  testWidgets('un fichero de más de 10 MB se rechaza sin subirlo', (tester) async {
    files.next = InvoiceFile(name: 'enorme.pdf', bytes: Uint8List(InvoicesRepository.maxBytes + 1));
    await pump(tester);

    await tester.tap(find.byKey(const Key('invoiceAttach')));
    await tester.pumpAndSettle();

    expect(api.sent('POST $path'), isEmpty);
    expect(find.text('La factura no puede superar los 10 MB.'), findsOneWidget);
  });

  testWidgets('el error de la API (tipo no admitido) se ve dentro de la ficha', (tester) async {
    api.on(
      'POST $path',
      (_) => FakeResponse(415, problem('unsupported-file-type', 415, detail: 'Solo PDF, JPEG, PNG o WebP.')),
    );
    files.next = InvoiceFile(name: 'nota.pdf', bytes: Uint8List.fromList([1, 2, 3]));
    await pump(tester);

    await tester.tap(find.byKey(const Key('invoiceAttach')));
    await tester.pumpAndSettle();

    expect(find.text('Solo PDF, JPEG, PNG o WebP.'), findsOneWidget);
    expect(find.byKey(const Key('invoiceAttach')), findsOneWidget, reason: 'se puede volver a intentar');
  });

  testWidgets('abrir un PDF lo descarga y se lo entrega al sistema', (tester) async {
    stored = metadata('luz.pdf', 'application/pdf', 900);
    final content = Uint8List.fromList([37, 80, 68, 70, 45]);
    api.on('GET $path', (_) => FakeResponse(200, content));
    await pump(tester);

    expect(find.textContaining('PDF · 900 B'), findsOneWidget);
    await tester.tap(find.byKey(const Key('invoiceTile')));
    await tester.pumpAndSettle();

    expect(files.opened.single.$1, content);
    expect(files.opened.single.$2, 'luz.pdf');
    expect(files.opened.single.$3, 'application/pdf');
  });

  testWidgets('quitar la factura pide confirmación', (tester) async {
    stored = metadata('luz.pdf', 'application/pdf', 900);
    api.on('DELETE $path', (_) {
      stored = null;
      return const FakeResponse(204);
    });
    await pump(tester);

    await tester.tap(find.byTooltip('Quitar factura'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(api.sent('DELETE $path'), isEmpty);

    await tester.tap(find.byTooltip('Quitar factura'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Quitar')));
    await tester.pumpAndSettle();

    expect(api.sent('DELETE $path'), hasLength(1));
    expect(find.byKey(const Key('invoiceAttach')), findsOneWidget);
  });

  testWidgets('quien no puede editar el gasto no puede adjuntar', (tester) async {
    await pump(tester, canEdit: false);

    expect(find.text('Este gasto no tiene factura.'), findsOneWidget);
    expect(find.byKey(const Key('invoiceAttach')), findsNothing);
  });

  testWidgets('quien no puede editar el gasto ve la factura pero no puede quitarla', (tester) async {
    stored = metadata('luz.pdf', 'application/pdf', 900);
    await pump(tester, canEdit: false);

    expect(find.text('luz.pdf'), findsOneWidget);
    expect(find.byTooltip('Quitar factura'), findsNothing);
  });

  test('formatBytes usa coma decimal', () {
    expect(formatBytes(950), '950 B');
    expect(formatBytes(188416), '184 KB');
    expect(formatBytes(1258291), '1,2 MB');
  });
}
