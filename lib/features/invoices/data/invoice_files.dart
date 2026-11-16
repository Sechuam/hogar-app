import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'invoices_repository.dart';

/// Lo que depende del dispositivo: elegir un fichero y entregarlo al sistema (abrir, guardar o
/// compartir). Separado para que los tests no toquen plugins nativos.
abstract interface class InvoiceFiles {
  /// `null` si el usuario cancela.
  Future<InvoiceFile?> pick();

  /// En móvil abre la hoja de compartir ("Abrir con…", "Guardar en Archivos"); en web descarga el fichero.
  Future<void> open(Uint8List bytes, {required String filename, required String contentType});
}

class PlatformInvoiceFiles implements InvoiceFiles {
  const PlatformInvoiceFiles();

  @override
  Future<InvoiceFile?> pick() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: InvoicesRepository.extensions);
    if (files.isEmpty) {
      return null;
    }
    final file = files.single;
    // Se mira el tamaño antes de leer: no hace falta cargar 200 MB en memoria para rechazarlos.
    final length = await file.length();
    if (length != null && length > InvoicesRepository.maxBytes) {
      throw InvoicesRepository.tooLarge;
    }
    return InvoiceFile(name: file.name, bytes: await file.readAsBytes());
  }

  @override
  Future<void> open(Uint8List bytes, {required String filename, required String contentType}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: contentType, name: filename)],
        fileNameOverrides: [filename],
        downloadFallbackEnabled: true,
      ),
    );
  }
}

final invoiceFilesProvider = Provider<InvoiceFiles>((ref) => const PlatformInvoiceFiles());
