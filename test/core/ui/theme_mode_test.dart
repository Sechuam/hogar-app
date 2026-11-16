import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogar_app/core/ui/theme.dart';
import 'package:hogar_app/core/ui/theme_mode.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPreferences> prefs([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  /// App mínima que usa el tema elegido, con el selector en pantalla.
  Future<void> pump(WidgetTester tester, SharedPreferences preferences) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ref.watch(themeModeProvider),
            home: const Scaffold(body: ThemeModeSelector()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Brightness brightness(WidgetTester tester) => Theme.of(tester.element(find.byType(ThemeModeSelector))).brightness;

  testWidgets('por defecto sigue al sistema', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pump(tester, await prefs());

    expect(brightness(tester), Brightness.dark);
    expect(find.text('Sigue el modo claro u oscuro del dispositivo.'), findsOneWidget);
  });

  testWidgets('elegir "Oscuro" cambia el tema y lo guarda', (tester) async {
    final preferences = await prefs();
    await pump(tester, preferences);
    expect(brightness(tester), Brightness.light);

    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();

    expect(brightness(tester), Brightness.dark);
    expect(preferences.getString(ThemeModeController.key), 'dark');
  });

  testWidgets('al arrancar usa el tema guardado aunque el sistema diga otra cosa', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pump(tester, await prefs({ThemeModeController.key: 'light'}));

    expect(brightness(tester), Brightness.light);
  });

  testWidgets('un valor guardado desconocido vuelve a "Sistema"', (tester) async {
    await pump(tester, await prefs({ThemeModeController.key: 'sepia'}));

    final selector = tester.widget<SegmentedButton<ThemeMode>>(find.byKey(const Key('themeMode')));
    expect(selector.selected, {ThemeMode.system});
  });
}
