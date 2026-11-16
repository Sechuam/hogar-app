import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';

import '../money/money.dart';
import 'theme.dart';

/// Ancho máximo del contenido: en tablet y web las listas no se estiran de lado a lado.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    // Alto del hijo: así también sirve en barras inferiores, no solo en el cuerpo.
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Iniciales y color estable por persona: el mismo miembro tiene el mismo color en toda la app.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.id, required this.name, this.radius = 20});

  final String id;
  final String name;
  final double radius;

  static const _hues = [140.0, 200.0, 265.0, 330.0, 25.0, 50.0, 175.0, 290.0];

  /// Color de fondo y de texto para [id], según el brillo del tema.
  static (Color, Color) colorsFor(String id, Brightness brightness) {
    final hue = _hues[id.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0x7fffffff) % _hues.length];
    final light = brightness == Brightness.light;
    return (
      HSLColor.fromAHSL(1, hue, light ? 0.55 : 0.35, light ? 0.86 : 0.30).toColor(),
      HSLColor.fromAHSL(1, hue, light ? 0.60 : 0.70, light ? 0.25 : 0.85).toColor(),
    );
  }

  static String initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) {
      return '?';
    }
    final first = words.first.characters.first;
    final second = words.length > 1 ? words[1].characters.first : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = colorsFor(id, Theme.of(context).brightness);
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: background,
        foregroundColor: foreground,
        child: Text(
          initials(name),
          style: TextStyle(fontSize: radius * 0.75, fontWeight: FontWeight.w700, color: foreground),
        ),
      ),
    );
  }
}

/// Importe con cifras tabulares; con [signed], verde si es positivo y rojo si es negativo.
class AmountText extends StatelessWidget {
  const AmountText(this.amount, this.currency, {super.key, this.style, this.signed = false});

  final Decimal amount;
  final String currency;
  final TextStyle? style;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final colors = MoneyColors.of(context);
    final color = !signed || amount == Decimal.zero
        ? null
        : amount > Decimal.zero
        ? colors.positive
        : colors.negative;
    final base = style ?? Theme.of(context).textTheme.titleMedium;
    return Text(
      Money.format(amount, currency),
      style: base?.copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}

/// Título de una sección de una lista, con una acción opcional a la derecha.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(4, 20, 4, 8)});

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Icono dentro de un cuadrado redondeado con color tonal (categorías, avisos).
class TonalIcon extends StatelessWidget {
  const TonalIcon(this.icon, {super.key, this.color, this.size = 44});

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = color ?? scheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: base.withValues(alpha: Theme.of(context).brightness == Brightness.light ? 0.14 : 0.24),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: base, size: size * 0.5),
    );
  }
}

/// Tarjeta destacada (resumen de una pestaña) con fondo en degradado del color primario.
class HighlightCard extends StatelessWidget {
  const HighlightCard({super.key, required this.child, this.color});

  final Widget child;

  /// Color base del degradado; por defecto, el contenedor primario.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = color ?? scheme.primaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, Color.lerp(base, scheme.surface, 0.35)!],
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}
