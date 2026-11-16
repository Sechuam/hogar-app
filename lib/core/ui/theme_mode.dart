import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias del dispositivo (no secretas). Se carga en `main` antes de arrancar la app para que el
/// primer fotograma ya salga con el tema elegido, sin parpadeo.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Se sustituye en main() con SharedPreferences.getInstance()'),
);

/// Tema elegido por el usuario: sistema (por defecto), claro u oscuro. Se guarda en el dispositivo.
class ThemeModeController extends Notifier<ThemeMode> {
  static const key = 'themeMode';

  @override
  ThemeMode build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(key);
    return ThemeMode.values.firstWhere((mode) => mode.name == saved, orElse: () => ThemeMode.system);
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

/// Selector Sistema / Claro / Oscuro, en una hoja inferior.
Future<void> showThemeModePicker(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  builder: (context) => const SafeArea(
    child: Padding(padding: EdgeInsets.fromLTRB(24, 0, 24, 24), child: ThemeModeSelector()),
  ),
);

class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Apariencia', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        SegmentedButton<ThemeMode>(
          key: const Key('themeMode'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('Sistema')),
            ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Claro')),
            ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Oscuro')),
          ],
          selected: {mode},
          onSelectionChanged: (selection) => ref.read(themeModeProvider.notifier).set(selection.single),
        ),
        const SizedBox(height: 12),
        Text(
          mode == ThemeMode.system ? 'Sigue el modo claro u oscuro del dispositivo.' : 'Se guarda en este dispositivo.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
