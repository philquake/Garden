import 'dart:math';

import 'package:flutter/material.dart';

import 'meadow_painter.dart';
import 'motion.dart';
import 'theme.dart';

/// Plays a watering animation over [child] each time [trigger] changes: wet
/// colour spreads up from the base like paint on paper, with soft droplets and
/// sometimes a visiting bee or butterfly. Reduced motion gets a brief tint.
class WaterEffect extends StatefulWidget {
  const WaterEffect({
    super.key,
    required this.child,
    required this.trigger,
    this.random,
  });
  final Widget child;
  final int trigger;
  final Random? random;

  @override
  State<WaterEffect> createState() => _WaterEffectState();
}

class _WaterEffectState extends State<WaterEffect>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this);
  final Random _fallback = Random();
  Random get _random => widget.random ?? _fallback;
  bool _visitor = false;
  bool _bee = false;
  bool _still = false;

  @override
  void didUpdateWidget(WaterEffect old) {
    super.didUpdateWidget(old);
    if (widget.trigger == old.trigger) return;
    _still = reduceMotion(context);
    _visitor = !_still && _random.nextDouble() < 0.3;
    _bee = _random.nextBool();
    _c.duration = Duration(milliseconds: _still ? 200 : 900);
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value;
        if (_c.isDismissed || t >= 1) return child!;
        // Fade the whole effect out over its last fifth.
        final fade = t > 0.8 ? (1 - t) / 0.2 : 1.0;
        final wet = skyBlue.withValues(alpha: 0.75 * fade);
        final front = _still ? 1.0 : Curves.easeOut.transform(t);
        Widget tinted = ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (r) => LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [wet, wet, wet.withValues(alpha: 0)],
            stops: [0, front, min(1.0, front + 0.3)],
          ).createShader(r),
          child: child,
        );
        if (_still) return tinted;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            tinted,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _DropPainter(t, fade)),
              ),
            ),
            if (_visitor)
              Positioned.fill(
                child: IgnorePointer(
                  child: LayoutBuilder(
                    builder: (context, box) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: -24 + (box.maxWidth + 48) * t,
                          top: box.maxHeight * 0.25 + 24 * sin(2 * pi * t * 2),
                          child: CustomPaint(
                            key: const Key('water-visitor'),
                            size: const Size(24, 24),
                            painter: InsectPainter(
                              bee: _bee,
                              flap: (sin(2 * pi * t * 30) + 1) / 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DropPainter extends CustomPainter {
  _DropPainter(this.t, this.fade);
  final double t;
  final double fade;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = skyBlue.withValues(alpha: 0.9 * fade);
    for (var i = 0; i < 5; i++) {
      final x = size.width * (0.3 + 0.1 * i);
      final y = size.height * (0.05 + 0.7 * ((t * 1.2 + i * 0.13) % 1.0));
      canvas.drawCircle(Offset(x, y), 3 + (i % 2) * 1.5, p);
    }
  }

  @override
  bool shouldRepaint(_DropPainter old) => old.t != t || old.fade != fade;
}
