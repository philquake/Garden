import 'dart:math';

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// FNV-1a 32-bit; String.hashCode is not stable across runs.
int stableHash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// Base point of a flower: one 150px slot per index, jittered by the id.
Offset flowerPosition(
  String habitId,
  int index,
  double meadowWidth,
  double meadowHeight,
) {
  final h = stableHash(habitId);
  final jx = ((h & 0xFFFF) / 0xFFFF - 0.5) * 30;
  final fy = ((h >> 16) & 0xFFFF) / 0xFFFF;
  final x = (75 + index * 150 + jx)
      .clamp(40.0, max(40.0, meadowWidth - 40))
      .toDouble();
  return Offset(x, meadowHeight * (0.5 + fy * 0.3));
}

/// Soft watercolour wash: layered translucent gradients and blobs.
class MeadowPainter extends CustomPainter {
  const MeadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skyBlue, skyMist, sageLight],
          stops: [0, 0.45, 1],
        ).createShader(rect),
    );
    final rnd = Random(7);
    void blob(Color c, double cy, double rh, int n) {
      for (var i = 0; i < n; i++) {
        final r = Rect.fromCenter(
          center: Offset(
            rnd.nextDouble() * size.width,
            cy + rnd.nextDouble() * rh,
          ),
          width: 160 + rnd.nextDouble() * 260,
          height: 70 + rnd.nextDouble() * 120,
        );
        canvas.drawOval(
          r,
          Paint()
            ..color = c.withValues(alpha: 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
        );
      }
    }

    blob(sage, size.height * 0.42, size.height * 0.1, size.width ~/ 120);
    blob(sageDeep, size.height * 0.6, size.height * 0.3, size.width ~/ 90);
    blob(
      dustyPink,
      size.height * 0.1,
      size.height * 0.2,
      size.width ~/ 300 + 1,
    );
    blob(honey, size.height * 0.05, size.height * 0.15, size.width ~/ 500 + 1);
  }

  @override
  bool shouldRepaint(MeadowPainter old) => false;
}

/// A tiny bee or butterfly.
class InsectPainter extends CustomPainter {
  const InsectPainter({required this.bee, required this.flap});
  final bool bee;
  final double flap; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final wing = Paint()
      ..color = (bee ? paper : dustyPink).withValues(alpha: 0.85);
    final w = size.width * (bee ? 0.22 : 0.3) * (0.5 + flap * 0.5);
    for (final dx in [-w, w]) {
      canvas.drawOval(
        Rect.fromCenter(center: c.translate(dx, -4), width: w * 2, height: 9),
        wing,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: c,
        width: size.width * 0.3,
        height: size.height * 0.5,
      ),
      Paint()..color = bee ? honey : inkBrown.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(InsectPainter old) => old.flap != flap;
}
