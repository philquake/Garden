import 'dart:math';

import 'package:flutter/material.dart';

import '../domain/day.dart';
import 'history.dart';

/// Hand-drawn charts: no chart package, so they match the flowers.

Color _faint(BuildContext c) =>
    Theme.of(c).colorScheme.onSurface.withValues(alpha: 0.10);

void _label(
  Canvas canvas,
  String text,
  Offset at,
  Color color, {
  bool centre = true,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: 10, color: color),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, centre ? at - Offset(tp.width / 2, 0) : at);
}

/// Circular score, 0..1, with the percentage in the middle.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    required this.color,
    this.size = 72,
  });

  final double score;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = '${(score * 100).round()}%';
    return Semantics(
      container: true,
      label: 'Score $label',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(score.clamp(0, 1), color, _faint(context)),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.score, this.color, this.track);
  final double score;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.shortestSide * 0.12;
    final rect = Offset.zero & size;
    final r = rect.deflate(w / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, 2 * pi, false, p..color = track);
    if (score > 0) {
      canvas.drawArc(r, -pi / 2, 2 * pi * score, false, p..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.score != score || old.color != color || old.track != track;
}

/// Score over time: one point per bucket, 0..100%.
class ScoreLine extends StatelessWidget {
  const ScoreLine({
    super.key,
    required this.buckets,
    required this.range,
    required this.color,
    this.height = 150,
  });

  final List<Bucket> buckets;
  final Range range;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final last = buckets.isEmpty ? 0.0 : buckets.last.score;
    return Semantics(
      container: true,
      label:
          'Score over time, now ${(last * 100).round()} percent, '
          'by ${range.name}',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _LinePainter(
            buckets,
            range,
            color,
            _faint(context),
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

String bucketLabel(Bucket b, Range r) => switch (r) {
  Range.week => shortDate(b.start),
  Range.month => monthNames[dateOf(b.start).month - 1],
  Range.year => '${dateOf(b.start).year}',
};

class _LinePainter extends CustomPainter {
  _LinePainter(this.b, this.range, this.color, this.grid, this.text);
  final List<Bucket> b;
  final Range range;
  final Color color;
  final Color grid;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 28.0, bottom = 18.0, top = 6.0;
    final w = size.width - left - 8;
    final h = size.height - bottom - top;
    double y(double v) => top + h * (1 - v);
    final line = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in [0.0, 0.5, 1.0]) {
      canvas.drawLine(Offset(left, y(v)), Offset(left + w, y(v)), line);
      _label(
        canvas,
        '${(v * 100).round()}%',
        Offset(0, y(v) - 6),
        text,
        centre: false,
      );
    }
    if (b.isEmpty) return;
    double x(int i) => left + (b.length == 1 ? w / 2 : w * i / (b.length - 1));
    final path = Path();
    for (var i = 0; i < b.length; i++) {
      final p = Offset(x(i), y(b[i].score));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final dot = Paint()..color = color;
    for (var i = 0; i < b.length; i++) {
      canvas.drawCircle(Offset(x(i), y(b[i].score)), 3, dot);
    }
    final step = (b.length / 6).ceil();
    for (var i = 0; i < b.length; i += step) {
      _label(
        canvas,
        bucketLabel(b[i], range),
        Offset(x(i), size.height - 13),
        text,
      );
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.b != b || old.color != color || old.range != range;
}

/// Days that met the goal per bucket.
class HistoryBars extends StatelessWidget {
  const HistoryBars({
    super.key,
    required this.buckets,
    required this.range,
    required this.color,
    this.height = 150,
  });

  final List<Bucket> buckets;
  final Range range;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = buckets.fold<int>(0, (a, b) => a + b.met);
    return Semantics(
      container: true,
      label: 'History by ${range.name}, $total days done',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _BarPainter(
            buckets,
            range,
            color,
            _faint(context),
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.b, this.range, this.color, this.grid, this.text);
  final List<Bucket> b;
  final Range range;
  final Color color;
  final Color grid;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    const bottom = 18.0, top = 14.0;
    final h = size.height - bottom - top;
    canvas.drawLine(
      Offset(0, top + h),
      Offset(size.width, top + h),
      Paint()..color = grid,
    );
    if (b.isEmpty) return;
    final maxV = max(1, b.map((e) => e.met).reduce(max));
    final slot = size.width / b.length;
    final barW = slot * 0.62;
    final paint = Paint()..color = color;
    final step = (b.length / 6).ceil();
    for (var i = 0; i < b.length; i++) {
      final cx = slot * (i + 0.5);
      final bh = h * b[i].met / maxV;
      if (b[i].met > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - barW / 2, top + h - bh, barW, bh),
            const Radius.circular(3),
          ),
          paint,
        );
        _label(canvas, '${b[i].met}', Offset(cx, top + h - bh - 13), text);
      }
      if (i % step == 0) {
        _label(
          canvas,
          bucketLabel(b[i], range),
          Offset(cx, size.height - 13),
          text,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.b != b || old.color != color || old.range != range;
}

/// Dense dot grid of the recent weeks (a column per week, Monday at the top),
/// as on a habit card.
class HeatStrip extends StatelessWidget {
  const HeatStrip({
    super.key,
    required this.marks,
    required this.today,
    required this.createdDay,
    required this.color,
  });

  final Map<int, Mark> marks;
  final int today;
  final int createdDay;
  final Color color;

  static const _cell = 11.0;

  @override
  Widget build(BuildContext context) {
    final faint = _faint(context);
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) {
          final cols = max(4, (box.maxWidth / _cell).floor());
          return SizedBox(
            height: 7 * _cell,
            width: double.infinity,
            child: CustomPaint(
              painter: _HeatPainter(
                marks,
                today,
                createdDay,
                color,
                faint,
                cols,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeatPainter extends CustomPainter {
  _HeatPainter(
    this.marks,
    this.today,
    this.created,
    this.color,
    this.faint,
    this.cols,
  );
  final Map<int, Mark> marks;
  final int today;
  final int created;
  final Color color;
  final Color faint;
  final int cols;

  @override
  void paint(Canvas canvas, Size size) {
    const cell = HeatStrip._cell;
    const r = 3.6;
    final thisWeek = weekIndex(today);
    // Right-align so the newest week sits at the right edge.
    final offset = size.width - cols * cell;
    for (var c = 0; c < cols; c++) {
      final weekStart = (thisWeek - (cols - 1 - c)) * 7 - 3;
      for (var row = 0; row < 7; row++) {
        final day = weekStart + row;
        if (day < created || day > today) continue;
        final centre = Offset(
          offset + c * cell + cell / 2,
          row * cell + cell / 2,
        );
        switch (marks[day] ?? Mark.none) {
          case Mark.met:
            canvas.drawCircle(centre, r, Paint()..color = color);
          case Mark.partial:
            canvas.drawCircle(
              centre,
              r,
              Paint()..color = color.withValues(alpha: 0.4),
            );
          case Mark.forgiven:
            canvas.drawCircle(
              centre,
              r - 0.8,
              Paint()
                ..color = color
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
          case Mark.none:
            canvas.drawCircle(centre, r, Paint()..color = faint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_HeatPainter old) =>
      old.marks != marks || old.today != today || old.cols != cols;
}
