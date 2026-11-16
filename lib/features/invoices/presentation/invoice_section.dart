import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/ui/async_view.dart';
import '../../../core/ui/dates.dart';
import '../../../core/ui/widgets.dart';
import '../../households/data/households_repository.dart';
import '../data/invoice_files.dart';
import '../data/invoices_repository.dart';

/// Factura de un gasto dentro de su ficha: verla, adjuntarla o quitarla.
///
/// Los errores se muestran aquí mismo y no en un SnackBar: la ficha es una hoja modal y el SnackBar
/// quedaría debajo, sin verse.
class InvoiceSection extends ConsumerStatefulWidget {
  const InvoiceSection({super.key, required this.householdId, required this.expenseId, required this.canEdit});

  final String householdId;
  final String expenseId;

  /// Pagador, quien creó el gasto o un OWNER (la API aplica la misma regla).
  final bool canEdit;

  @override
  ConsumerState<InvoiceSection> createState() => _InvoiceSectionState();
}

class _InvoiceSectionState extends ConsumerState<InvoiceSection> {
  bool _busy = false;
  String? _error;

  (String, String) get _key => (widget.householdId, widget.expenseId);

  @override
  Widget build(BuildContext context) {
    final invoice = ref.watch(invoiceProvider(_key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Factura', padding: EdgeInsets.only(top: 24, bottom: 8)),
        switch (invoice) {
          AsyncData(:final value) => value == null ? _empty(context) : _attached(context, value),
          AsyncError(:final error) => _LoadError(
            message: errorMessage(error),
            onRetry: () => ref.invalidate(invoiceProvider(_key)),
          ),
          _ => const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator()),
        },
        if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              _error!,
              key: const Key('invoiceError'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!widget.canEdit) {
      return Text('Este gasto no tiene factura.', style: TextStyle(color: scheme.onSurfaceVariant));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: const Key('invoiceAttach'),
          onPressed: _busy ? null : _attach,
          icon: const Icon(Icons.attach_file),
          label: const Text('Adjuntar factura'),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'PDF o foto (JPEG, PNG, WebP), hasta 10 MB.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _attached(BuildContext context, Invoice invoice) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        key: const Key('invoiceTile'),
        leading: TonalIcon(invoice.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined, size: 40),
        title: Text(invoice.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${typeLabel(invoice.contentType)} · ${formatBytes(invoice.sizeBytes)} · '
          '${Dates.shortDay(invoice.createdAt.toLocal())}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: widget.canEdit
            ? IconButton(
                tooltip: 'Quitar factura',
                onPressed: _busy ? null : () => _delete(invoice),
                icon: const Icon(Icons.delete_outline),
              )
            : const Icon(Icons.open_in_new),
        onTap: _busy ? null : () => _view(invoice),
      ),
    );
  }

  Future<void> _attach() async {
    await _run(() async {
      final file = await ref.read(invoiceFilesProvider).pick();
      if (file == null) {
        return;
      }
      await ref.read(invoicesRepositoryProvider).upload(widget.householdId, widget.expenseId, file);
      _refresh();
    });
  }

  Future<void> _view(Invoice invoice) async {
    Uint8List? bytes;
    await _run(() async {
      bytes = await ref.read(invoicesRepositoryProvider).download(widget.householdId, widget.expenseId);
    });
    final content = bytes;
    if (content == null || !mounted) {
      return;
    }
    if (invoice.isImage) {
      await showDialog<void>(
        context: context,
        builder: (context) =>
            _ImagePreview(bytes: content, filename: invoice.filename, onOpen: () => _open(content, invoice)),
      );
    } else {
      await _open(content, invoice);
    }
  }

  Future<void> _open(Uint8List bytes, Invoice invoice) => _run(
    () => ref.read(invoiceFilesProvider).open(bytes, filename: invoice.filename, contentType: invoice.contentType),
  );

  Future<void> _delete(Invoice invoice) async {
    final ok = await confirm(
      context,
      title: 'Quitar factura',
      message: '¿Quitar "${invoice.filename}" de este gasto? El gasto no cambia.',
      confirmLabel: 'Quitar',
    );
    if (!ok) {
      return;
    }
    await _run(() async {
      await ref.read(invoicesRepositoryProvider).delete(widget.householdId, widget.expenseId);
      _refresh();
    });
  }

  /// La factura y el espacio usado del plan.
  void _refresh() => ref
    ..invalidate(invoiceProvider(_key))
    ..invalidate(planProvider(widget.householdId));

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => _error = errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(message)),
      TextButton(onPressed: onRetry, child: const Text('Reintentar')),
    ],
  );
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.bytes, required this.filename, required this.onOpen});

  final Uint8List bytes;
  final String filename;
  final Future<void> Function() onOpen;

  @override
  Widget build(BuildContext context) => Dialog(
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: InteractiveViewer(
            maxScale: 5,
            child: Image.memory(bytes, fit: BoxFit.contain, semanticLabel: filename),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(child: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis)),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
              FilledButton.tonalIcon(
                onPressed: onOpen,
                icon: const Icon(Icons.ios_share),
                label: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String typeLabel(String contentType) => switch (contentType) {
  'application/pdf' => 'PDF',
  'image/jpeg' => 'JPEG',
  'image/png' => 'PNG',
  'image/webp' => 'WebP',
  _ => contentType,
};
