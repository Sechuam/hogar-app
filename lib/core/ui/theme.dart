import 'package:material_ui/material_ui.dart';

/// Tema de la app: Material 3 a partir de un verde "hogar", con formas redondeadas y superficies
/// tonales en vez de sombras. Los colores del dinero van en [MoneyColors].
abstract final class AppTheme {
  static const seed = Color(0xFF2E7D32);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final base = ThemeData(colorScheme: scheme, brightness: brightness);
    final text = base.textTheme;
    const radius = BorderRadius.all(Radius.circular(16));

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      // Misma transición entre pantallas en todas las plataformas (también en web).
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {for (final platform in TargetPlatform.values) platform: const FadeForwardsPageTransitionsBuilder()},
      ),
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.25),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 12,
      ),
      // Relleno con la etiqueta dentro del fondo (estilo "filled" de Material 3): con un borde
      // "outline" la etiqueta flotante se dibuja sobre el borde superior e invade lo que hay encima.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        border: const UnderlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: const UnderlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        focusedBorder: UnderlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: const RoundedRectangleBorder(borderRadius: radius),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: const RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: const RoundedRectangleBorder(borderRadius: radius)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: const RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: text.labelMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        linearMinHeight: 6,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), space: 1),
      extensions: [MoneyColors.forBrightness(brightness)],
    );
  }
}

/// Colores con significado para importes: a favor (te deben) y en contra (debes).
@immutable
class MoneyColors extends ThemeExtension<MoneyColors> {
  const MoneyColors({
    required this.positive,
    required this.positiveContainer,
    required this.negative,
    required this.negativeContainer,
  });

  factory MoneyColors.forBrightness(Brightness brightness) => brightness == Brightness.light
      ? const MoneyColors(
          positive: Color(0xFF1B7A3A),
          positiveContainer: Color(0xFFD6F5DD),
          negative: Color(0xFFB3261E),
          negativeContainer: Color(0xFFFCE1DE),
        )
      : const MoneyColors(
          positive: Color(0xFF7DDB98),
          positiveContainer: Color(0xFF14391F),
          negative: Color(0xFFFFB4AB),
          negativeContainer: Color(0xFF4A1612),
        );

  final Color positive;
  final Color positiveContainer;
  final Color negative;
  final Color negativeContainer;

  static MoneyColors of(BuildContext context) =>
      Theme.of(context).extension<MoneyColors>() ?? MoneyColors.forBrightness(Theme.of(context).brightness);

  @override
  MoneyColors copyWith({Color? positive, Color? positiveContainer, Color? negative, Color? negativeContainer}) =>
      MoneyColors(
        positive: positive ?? this.positive,
        positiveContainer: positiveContainer ?? this.positiveContainer,
        negative: negative ?? this.negative,
        negativeContainer: negativeContainer ?? this.negativeContainer,
      );

  @override
  MoneyColors lerp(MoneyColors? other, double t) => other == null
      ? this
      : MoneyColors(
          positive: Color.lerp(positive, other.positive, t)!,
          positiveContainer: Color.lerp(positiveContainer, other.positiveContainer, t)!,
          negative: Color.lerp(negative, other.negative, t)!,
          negativeContainer: Color.lerp(negativeContainer, other.negativeContainer, t)!,
        );
}
