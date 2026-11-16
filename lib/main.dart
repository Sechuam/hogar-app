import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/ui/theme_mode.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      // Sin reintentos automáticos de Riverpod: los errores se muestran con un botón "Reintentar".
      retry: (retryCount, error) => null,
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const HogarApp(),
    ),
  );
}
