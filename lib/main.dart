import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';

void main() {
  // Sin reintentos automáticos de Riverpod: los errores se muestran con un botón "Reintentar".
  runApp(ProviderScope(retry: (retryCount, error) => null, child: const HogarApp()));
}
