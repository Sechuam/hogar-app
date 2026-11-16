import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';

import '../money/money.dart';

/// Duraciones y curvas comunes: todas las animaciones de la app comparten ritmo.
abstract final class Motion {
  static const short = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const long = Duration(milliseconds: 600);
  static const curve = Curves.easeOutCubic;

  /// Respeta "reducir movimiento" del sistema: sin animaciones, todo aparece a la vez.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Entrada de un elemento de lista: aparece y sube unos píxeles. [index] escalona la entrada (con
/// tope, para que una lista larga no tarde en llenarse). Solo se anima al crearse, no al reconstruirse.
class Appear extends StatefulWidget {
  const Appear({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  // El retraso va dentro de la propia animación (un Interval) y no en un temporizador aparte: así no
  // quedan temporizadores pendientes si el widget desaparece antes de empezar.
  static const _stepMs = 40;
  late final int _delayMs = _stepMs * widget.index.clamp(0, 8);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _delayMs) + Motion.medium,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Interval(_delayMs / (_delayMs + Motion.medium.inMilliseconds), 1, curve: Motion.curve),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _controller.value = 1;
    } else if (_controller.isDismissed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: _progress.value,
      child: Transform.translate(offset: Offset(0, 12 * (1 - _progress.value)), child: child),
    ),
  );
}

/// Importe que "cuenta" hasta su valor al aparecer o cambiar. Se anima en céntimos enteros: el
/// dinero nunca pasa por `double`.
class AnimatedAmount extends StatelessWidget {
  const AnimatedAmount(this.amount, this.currency, {super.key, this.style});

  final Decimal amount;
  final String currency;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final cents = (amount * Decimal.fromInt(100)).toBigInt().toInt();
    final base = (style ?? Theme.of(context).textTheme.headlineMedium)?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: cents),
      duration: Motion.reduced(context) ? Duration.zero : Motion.long,
      curve: Motion.curve,
      builder: (context, value, _) => Text(
        Money.format((Decimal.fromInt(value) / Decimal.fromInt(100)).toDecimal(scaleOnInfinitePrecision: 2), currency),
        style: base,
        semanticsLabel: Money.format(amount, currency),
      ),
    );
  }
}

/// Marcador de posición con brillo mientras carga la primera vez (en vez de un círculo girando).
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.cards = 3, this.highlight = true});

  /// Tarjetas de lista que se simulan.
  final int cards;

  /// Si se simula también la tarjeta destacada de arriba.
  final bool highlight;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Motion.reduced(context) && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final shine = scheme.surfaceContainerLow;
    Widget bone(double width, double height, {double radius = 8}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
    );
    final content = ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        if (widget.highlight) ...[bone(double.infinity, 120, radius: 24), const SizedBox(height: 24)],
        for (var i = 0; i < widget.cards; i++) ...[
          bone(120, 14),
          const SizedBox(height: 12),
          Row(
            children: [
              bone(44, 44, radius: 14),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [bone(double.infinity, 14), const SizedBox(height: 8), bone(100, 12)],
                ),
              ),
              const SizedBox(width: 24),
              bone(64, 16),
            ],
          ),
          const SizedBox(height: 28),
        ],
      ],
    );
    return Semantics(
      label: 'Cargando',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          child: content,
          builder: (context, child) => ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, shine, base],
              stops: const [0.2, 0.5, 0.8],
              transform: _SlideGradient(_controller.value),
            ).createShader(bounds),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.progress);

  final double progress;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (progress * 2 - 1), 0, 0);
}
