import 'package:material_ui/material_ui.dart';

import 'motion.dart';

/// Un tramo de [SegmentBar]: su peso relativo y su color.
class Segment {
  const Segment({required this.weight, required this.color, required this.label});

  /// Proporción relativa (p. ej. céntimos). Solo para dibujar: los importes se muestran aparte.
  final int weight;
  final Color color;
  final String label;
}

/// Barra horizontal partida en tramos proporcionales (reparto de un total). Crece al aparecer.
class SegmentBar extends StatelessWidget {
  const SegmentBar({super.key, required this.segments, this.height = 10});

  final List<Segment> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final visible = segments.where((s) => s.weight > 0).toList();
    final total = visible.fold<int>(0, (sum, s) => sum + s.weight);
    return Semantics(
      label: visible.map((s) => '${s.label} ${(s.weight * 100 / total).round()} %').join(', '),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.reduced(context) ? Duration.zero : Motion.long,
        curve: Motion.curve,
        builder: (context, grow, _) => ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: SizedBox(
            height: height,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: grow,
                child: Row(
                  children: [
                    for (final (i, s) in visible.indexed)
                      Expanded(
                        flex: s.weight,
                        child: Container(
                          margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
                          color: s.color,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra centrada en cero: a la derecha si es positivo y a la izquierda si es negativo. [fraction]
/// es el valor relativo al mayor (de -1 a 1).
class DivergingBar extends StatelessWidget {
  const DivergingBar({super.key, required this.fraction, required this.positive, required this.negative});

  final double fraction;
  final Color positive;
  final Color negative;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction.clamp(-1, 1)),
        duration: Motion.reduced(context) ? Duration.zero : Motion.long,
        curve: Motion.curve,
        builder: (context, value, _) => SizedBox(
          height: 6,
          child: Row(
            children: [
              Expanded(
                child: _Half(value: value < 0 ? -value : 0, color: negative, track: track, alignRight: true),
              ),
              Container(width: 2, color: Theme.of(context).colorScheme.outlineVariant),
              Expanded(
                child: _Half(value: value > 0 ? value : 0, color: positive, track: track, alignRight: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Half extends StatelessWidget {
  const _Half({required this.value, required this.color, required this.track, required this.alignRight});

  final double value;
  final Color color;
  final Color track;
  final bool alignRight;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(3)),
    child: Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value,
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
      ),
    ),
  );
}

/// Cifra pequeña con etiqueta, para resúmenes (p. ej. "2 · Vencidas").
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, required this.icon, required this.color});

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: light ? 0.12 : 0.22),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
