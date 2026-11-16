import 'package:material_ui/material_ui.dart';

/// Logotipo de la app: icono en un cuadrado con degradado.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, Color.lerp(scheme.primary, scheme.tertiary, 0.6)!],
        ),
        boxShadow: [
          BoxShadow(color: scheme.primary.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Icon(Icons.home_work_rounded, size: size * 0.5, color: scheme.onPrimary),
    );
  }
}
