import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/providers.dart';

/// Metadatos de la factura de un gasto (el contenido se descarga aparte).
class Invoice {
  const Invoice({
    required this.id,
    required this.contentType,
    required this.sizeBytes,
    required this.filename,
    required this.uploadedBy,
    required this.createdAt,
  });

  factory Invoice.fromJson(Json json) => Invoice(
    id: json['id'] as String,
    contentType: json['contentType'] as String,
    sizeBytes: json['sizeBytes'] as int,
    filename: json['filename'] as String,
    uploadedBy: json['uploadedBy'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  final String id;

  /// Tipo detectado por el servidor a partir del contenido, no el que declaró el cliente.
  final String contentType;
  final int sizeBytes;
  final String filename;
  final String uploadedBy;
  final DateTime createdAt;

  bool get isImage => contentType.startsWith('image/');
}

/// Fichero elegido por el usuario, ya leído en memoria (máximo [InvoicesRepository.maxBytes]).
class InvoiceFile {
  const InvoiceFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class InvoicesRepository {
  InvoicesRepository(this._api);

  /// Mismo límite que la API: se comprueba antes de subir para no gastar datos en balde.
  static const maxBytes = 10 * 1024 * 1024;

  /// Extensiones que se ofrecen al elegir; quien decide de verdad es la API, por el contenido.
  static const extensions = ['pdf', 'jpg', 'jpeg', 'png', 'webp'];

  /// El mismo error que daría la API (413), sin llegar a enviarlo.
  static const tooLarge = ApiException(
    code: 'file-too-large',
    message: 'La factura no puede superar los 10 MB.',
    status: 413,
  );

  final ApiClient _api;

  String _path(String householdId, String expenseId) => '/api/households/$householdId/expenses/$expenseId/invoice';

  /// `null` si el gasto no tiene factura.
  Future<Invoice?> metadata(String householdId, String expenseId) async {
    try {
      return Invoice.fromJson(await _api.get('${_path(householdId, expenseId)}/metadata') as Json);
    } on ApiException catch (e) {
      if (e.code == 'invoice-not-found') {
        return null;
      }
      rethrow;
    }
  }

  Future<Invoice> upload(String householdId, String expenseId, InvoiceFile file) async {
    if (file.bytes.length > maxBytes) {
      throw tooLarge;
    }
    final json = await _api.upload(
      _path(householdId, expenseId),
      () => FormData.fromMap({'file': MultipartFile.fromBytes(file.bytes, filename: file.name)}),
    );
    return Invoice.fromJson(json as Json);
  }

  Future<Uint8List> download(String householdId, String expenseId) => _api.getBytes(_path(householdId, expenseId));

  Future<void> delete(String householdId, String expenseId) => _api.delete(_path(householdId, expenseId));
}

final invoicesRepositoryProvider = Provider<InvoicesRepository>(
  (ref) => InvoicesRepository(ref.watch(apiClientProvider)),
);

/// Factura de un gasto, por `(householdId, expenseId)`; `null` si no tiene.
final invoiceProvider = FutureProvider.family<Invoice?, (String, String)>(
  (ref, key) => ref.watch(invoicesRepositoryProvider).metadata(key.$1, key.$2),
);
