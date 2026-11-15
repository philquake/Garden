import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../ui/theme.dart';
import 'look.dart';

/// Shape numbers for one growth stage, in a 100 x 100 box with the ground at
/// y = 95. Growing is a lerp between two of these.
class _Shape {
  const _Shape(
    this.headY,
    this.r,
    this.petal,
    this.leaf,
    this.stem,
    this.mound,
    this.green,
    this.seed,
  );
  final double headY, r, petal, leaf, stem, mound, green, seed;

  static const _stages = [
    _Shape(81, 13, 0, 0, 0, 1, 0, 1), // seed peeking out of a soil mound
    _Shape(66, 11, 0, 0.6, 1, 0, 1, 0), // sprout: face on a green bud
    _Shape(55, 13, 0.4, 0.8, 1, 0, 0, 0), // closed bud
    _Shape(45, 14.5, 0.72, 1, 1, 0, 0, 0), // half open
    _Shape(39, 16, 1, 1, 1, 0, 0, 0), // full bloom
  ];

  static _Shape at(double stage) {
    final s = stage.clamp(0.0, _stages.length - 1.0);
    final i = min(s.floor(), _stages.length - 2);
    final a = _stages[i], b = _stages[i + 1];
    double l(double x, double y) => lerpDouble(x, y, s - i)!;
    return _Shape(
      l(a.headY, b.headY),
      l(a.r, b.r),
      l(a.petal, b.petal),
      l(a.leaf, b.leaf),
      l(a.stem, b.stem),
      l(a.mound, b.mound),
      l(a.green, b.green),
      l(a.seed, b.seed),
    );
  }
}

final _faceYellow = Color.lerp(honey, paper, 0.3)!;
final _sunflowerFace = Color.lerp(honey, paper, 0.12)!;
final _budGreen = Color.lerp(sageLight, honey, 0.35)!;
final _seedTan = Color.lerp(honey, inkBrown, 0.3)!;
final _soil = Color.lerp(inkBrown, honey, 0.3)!;
final _daisyWhite = Color.lerp(paper, Colors.white, 0.7)!;
final _dropBlue = HSLColor.fromColor(skyBlue)
    .withSaturation(0.55)
    .withLightness(0.62)
    .toColor();

/// Draws one flower character. Every moving value is passed in, so a still
/// flower is just the defaults.
class FlowerPainter extends CustomPainter {
  const FlowerPainter({
    required this.look,
    required this.stage,
    required this.bend,
    this.sway = 0,
    this.breathe = 0,
    this.blink = 0,
    this.gaze = 0,
    this.delight,
  });

  final FlowerLook look;

  /// Growth stage, fractional while growing.
  final double stage;

  /// 0 upright .. 1 fully slumped.
  final double bend;

  /// Lean in radians.
  final double sway;

  /// Head swell for the sleepy breathing, -1..1.
  final double breathe;

  /// 0 eyes open .. 1 shut.
  final double blink;

  /// Sideways glance, -1..1.
  final double gaze;

  /// Progress 0..1 through the just-watered reaction, or null.
  final double? delight;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide / 100;
    if (u <= 0 || !u.isFinite) return;
    final fine = size.shortestSide >= 80;
    canvas.save();
    canvas.scale(u);

    final inkW = max(2.0, 1.3 / u);
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..color = inkBrown
      ..strokeWidth = inkW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Paint fill(Color c) => Paint()..color = c;

    final p = _Shape.at(stage);
    final d = delight;
    final stemLen = 95 - p.headY;
    final reach = stemLen / 56; // 1 at full bloom
    final bounce = d == null ? 0.0 : sin(pi * d) * 7 * max(0.4, reach);
    final lean = sway + bend * 0.5;
    final head = Offset(
      50 + sin(sway) * stemLen + bend * 15 * reach,
      p.headY + bend * 17 * reach - bounce,
    );
    const base = Offset(50, 95);
    final petalColor = switch (look.kind) {
      'tulip' => dustyPink,
      'sunflower' => honey,
      'lavender' => lavender,
      _ => _daisyWhite,
    };
    final slump = look.pose == Pose.slump;

    // Fallen petals lie on the ground.
    if (slump && p.petal > 0.3) {
      for (final (x, y, a) in [(27.0, 94.0, -0.3), (72.0, 95.0, 0.4)]) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(a);
        final oval = Rect.fromCenter(center: Offset.zero, width: 9, height: 5);
        canvas.drawOval(oval, fill(petalColor));
        canvas.drawOval(oval, ink);
        canvas.restore();
      }
    }

    // Stem, bending towards the head.
    final ctrl = Offset(50, (95 + head.dy) / 2);
    if (p.stem > 0.05) {
      final stem = Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, head.dx, head.dy);
      canvas.drawPath(stem, ink..strokeWidth = (3.2 + inkW) * p.stem);
      canvas.drawPath(
        stem,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..color = sageDeep
          ..strokeWidth = 3.2 * p.stem,
      );
      ink.strokeWidth = inkW;
    }

    // Two leaves that work as hands.
    final leafLen = 16 * p.leaf;
    if (leafLen > 1) {
      const t = 0.42;
      final at =
          base * ((1 - t) * (1 - t)) +
          ctrl * (2 * (1 - t) * t) +
          head * (t * t);
      final clap = d == null ? 0.0 : sin(d * pi * 5).abs() * 0.8;
      final angle = 0.55 - bend * 1.3 + clap;
      final leaf = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(leafLen * 0.5, -leafLen * 0.4, leafLen, 0)
        ..quadraticBezierTo(leafLen * 0.5, leafLen * 0.4, 0, 0);
      for (final side in [1.0, -1.0]) {
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.scale(side, 1);
        canvas.rotate(-angle);
        canvas.drawPath(leaf, fill(sage));
        canvas.drawPath(leaf, ink);
        canvas.restore();
      }
    }

    final r = p.r * (1 + 0.03 * breathe);

    // Petals, behind the face.
    if (p.petal > 0.02) {
      canvas.save();
      canvas.translate(head.dx, head.dy);
      canvas.rotate(lean);
      _petals(canvas, r, p.petal, petalColor, ink, slump);
      canvas.restore();
    }

    // Face disc.
    final yellow = look.kind == 'sunflower' ? _sunflowerFace : _faceYellow;
    final faceColor = Color.lerp(
      Color.lerp(yellow, _budGreen, p.green),
      _seedTan,
      p.seed,
    )!;
    canvas.drawCircle(head, r, fill(faceColor));
    canvas.drawCircle(head, r, ink);

    // Features, in a space where the head radius is 16.
    canvas.save();
    canvas.translate(head.dx, head.dy);
    canvas.rotate(lean);
    canvas.scale(r / 16);
    _features(canvas, ink..strokeWidth = inkW * 16 / r, fine);
    ink.strokeWidth = inkW;
    canvas.restore();

    // Soil mound over the seed's chin.
    if (p.mound > 0.02) {
      final mound = Path()
        ..moveTo(22, 98)
        ..quadraticBezierTo(50, 98 - 19 * p.mound, 78, 98)
        ..close();
      canvas.drawPath(mound, fill(_soil));
      canvas.drawPath(mound, ink);
    }

    if (look.bubble) _bubble(canvas, head, r * (1 + p.petal * 0.7), ink);

    canvas.restore();
  }

  void _petals(
    Canvas canvas,
    double r,
    double open,
    Color color,
    Paint ink,
    bool slump,
  ) {
    final paint = Paint()..color = color;
    void each(int n, double Function(int i) angle, void Function() draw) {
      for (var i = 0; i < n; i++) {
        if (slump && i % 3 == 1) continue; // lost petals
        canvas.save();
        canvas.rotate(angle(i));
        draw();
        canvas.restore();
      }
    }

    double ring(int i, int n) => 2 * pi * i / n - pi / 2;
    switch (look.kind) {
      case 'tulip':
        // Five tall petals cupping the face from behind; outer ones first.
        const order = [-2, 2, -1, 1, 0];
        final len = r * (0.35 + 1.0 * open), w = r * 0.9;
        each(5, (i) => -pi / 2 + order[i] * 0.62, () {
          final petal = Path()
            ..moveTo(r * 0.5, -w / 2)
            ..quadraticBezierTo(r * 0.5 + len * 0.9, -w / 2, r * 0.6 + len, 0)
            ..quadraticBezierTo(r * 0.5 + len * 0.9, w / 2, r * 0.5, w / 2)
            ..close();
          canvas.drawPath(petal, paint);
          canvas.drawPath(petal, ink);
        });
      case 'sunflower':
        final len = r * (0.25 + 0.75 * open), w = r * 0.44;
        each(14, (i) => ring(i, 14), () {
          final petal = Path()
            ..moveTo(r * 0.75, -w / 2)
            ..quadraticBezierTo(r * 0.75 + len * 0.6, -w / 2, r * 0.75 + len, 0)
            ..quadraticBezierTo(r * 0.75 + len * 0.6, w / 2, r * 0.75, w / 2)
            ..close();
          canvas.drawPath(petal, paint);
          canvas.drawPath(petal, ink);
        });
      case 'lavender':
        final pr = r * 0.34 * (0.45 + 0.55 * open);
        final at = Offset(r * (0.9 + 0.28 * open), 0);
        each(12, (i) => ring(i, 12), () {
          canvas.drawCircle(at, pr, paint);
          canvas.drawCircle(at, pr, ink);
        });
      default: // daisy
        final len = r * (0.3 + 0.8 * open), w = r * 0.56;
        each(10, (i) => ring(i, 10), () {
          final oval = Rect.fromLTWH(r * 0.7, -w / 2, len, w);
          canvas.drawOval(oval, paint);
          canvas.drawOval(oval, ink);
        });
    }
  }

  void _features(Canvas canvas, Paint ink, bool fine) {
    final d = delight;
    final delighted = d != null && d < 0.85;
    final face = look.face;
    final solid = Paint()..color = inkBrown;

    // Eyes.
    final (gx, gy) = switch (face) {
      Face.hopeful => (0.0, -1.3),
      Face.sad => (0.0, 1.0),
      Face.curious => (gaze * 1.6, 0.0),
      _ => (0.0, 0.0),
    };
    final k = switch (face) {
      Face.expectant || Face.curious => 1.15,
      Face.sad => 0.9,
      _ => 1.0,
    };
    for (final side in [-1.0, 1.0]) {
      final c = Offset(side * 6.2 + gx, -1.5 + gy);
      if (delighted) {
        // Squeezed shut with joy.
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 3, c.dy + 1.2)
            ..quadraticBezierTo(c.dx, c.dy - 3.2, c.dx + 3, c.dy + 1.2),
          ink,
        );
      } else if (face == Face.asleep || face == Face.sleepy) {
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 3, c.dy)
            ..quadraticBezierTo(c.dx, c.dy + 2.8, c.dx + 3, c.dy),
          ink,
        );
      } else {
        final ry = 3.4 * k * (1 - 0.9 * blink);
        canvas.drawOval(
          Rect.fromCenter(center: c, width: 4.8 * k, height: 2 * ry),
          solid,
        );
        if (ry > 1.6) {
          canvas.drawCircle(
            c + const Offset(-0.7, -1.2),
            0.95,
            Paint()..color = Colors.white,
          );
        }
      }
    }

    // Brows carry worry and hope.
    if (!delighted) {
      final (inner, outer) = switch (face) {
        Face.sad || Face.worried => (-9.4, -6.6),
        Face.hopeful || Face.expectant when fine => (-8.6, -8.6),
        _ => (0.0, 0.0),
      };
      if (inner != 0) {
        for (final side in [-1.0, 1.0]) {
          canvas.drawLine(
            Offset(side * 3.6, inner),
            Offset(side * 8.6, outer),
            ink,
          );
        }
      }
    }

    // Mouth.
    void curve(double halfW, double y, double dip) => canvas.drawPath(
      Path()
        ..moveTo(-halfW, y)
        ..quadraticBezierTo(0, y + dip, halfW, y),
      ink,
    );
    if (delighted || face == Face.grin) {
      final grin = Path()
        ..moveTo(-5.6, 4)
        ..quadraticBezierTo(0, 14, 5.6, 4)
        ..close();
      canvas.drawPath(grin, solid);
      canvas.drawPath(grin, ink);
    } else {
      switch (face) {
        case Face.sad:
          curve(4, 8.6, -4.4);
        case Face.worried:
          curve(3.4, 7.4, -2.2);
        case Face.curious:
          canvas.drawCircle(const Offset(0, 7), 1.7, ink);
        case Face.asleep || Face.sleepy:
          curve(2.4, 6.2, 2.2);
        default:
          curve(4, 5.2, 4.2);
      }
    }

    if (!fine) return;
    if (delighted || face == Face.grin || face == Face.content) {
      final cheek = Paint()..color = dustyPink.withValues(alpha: 0.85);
      canvas.drawCircle(const Offset(-11, 4.5), 2.3, cheek);
      canvas.drawCircle(const Offset(11, 4.5), 2.3, cheek);
    }
    if (face == Face.sad && !delighted) {
      // One tear, never more.
      final tear = Path()
        ..moveTo(-6.2, 3)
        ..cubicTo(-4.2, 5.6, -4.6, 8, -6.2, 8)
        ..cubicTo(-7.8, 8, -8.2, 5.6, -6.2, 3);
      canvas.drawPath(tear, Paint()..color = _dropBlue);
      canvas.drawPath(tear, ink..strokeWidth = ink.strokeWidth * 0.6);
    }
  }

  void _bubble(Canvas canvas, Offset head, double reach, Paint ink) {
    final c = Offset(
      (head.dx + reach * 0.75 + 9).clamp(12.0, 88.0),
      (head.dy - reach * 0.75 - 7).clamp(12.0, 82.0),
    );
    final white = Paint()..color = Colors.white;
    final towards = head - c;
    final dist = towards.distance;
    if (dist > 14) {
      final dot = c + towards / dist * 12.5;
      canvas.drawCircle(dot, 1.8, white);
      canvas.drawCircle(dot, 1.8, ink);
    }
    canvas.drawCircle(c, 9.5, white);
    canvas.drawCircle(c, 9.5, ink);
    final drop = Path()
      ..moveTo(c.dx, c.dy - 6)
      ..cubicTo(
        c.dx + 5.5,
        c.dy + 0.5,
        c.dx + 3.8,
        c.dy + 5.5,
        c.dx,
        c.dy + 5.5,
      )
      ..cubicTo(c.dx - 3.8, c.dy + 5.5, c.dx - 5.5, c.dy + 0.5, c.dx, c.dy - 6);
    canvas.drawPath(drop, Paint()..color = _dropBlue);
    canvas.drawPath(drop, ink);
  }

  @override
  bool shouldRepaint(FlowerPainter old) =>
      old.look != look ||
      old.stage != stage ||
      old.bend != bend ||
      old.sway != sway ||
      old.breathe != breathe ||
      old.blink != blink ||
      old.gaze != gaze ||
      old.delight != delight;
}
