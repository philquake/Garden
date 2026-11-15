import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../ui/motion.dart';
import 'flower_painter.dart';
import 'look.dart';

const _growSeconds = 0.6;
const _bendSeconds = 1.0;
const _delightSeconds = 0.9;

double _bendOf(Pose p) => switch (p) {
  Pose.upright => 0,
  Pose.droop => 0.55,
  Pose.slump => 1,
};

/// A live flower: sways, blinks, reacts to a watering and grows between
/// stages. With reduced motion it stands still and only its look changes.
class FlowerView extends StatefulWidget {
  const FlowerView({
    super.key,
    required this.look,
    required this.size,
    this.seed = 0,
    this.delightTrigger = 0,
  });

  final FlowerLook look;

  /// Width and height in logical pixels; the flower stands on the bottom.
  final double size;

  /// Offsets sway and blink so neighbours do not move in step.
  final int seed;

  /// Each change plays the just-watered reaction.
  final int delightTrigger;

  @override
  State<FlowerView> createState() => _FlowerViewState();
}

class _FlowerViewState extends State<FlowerView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// Seconds of animation shown so far; frozen while still.
  final _now = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (elapsed) => _now.value = _startedAt + elapsed.inMicroseconds / 1e6,
  );
  double _startedAt = 0;
  bool _still = false;

  // Each tween runs from a value captured at a moment on the clock.
  late double _stageFrom = widget.look.stage.toDouble();
  double _stageAt = double.negativeInfinity;
  late double _bendFrom = _bendOf(widget.look.pose);
  double _bendAt = double.negativeInfinity;
  double _delightAt = double.negativeInfinity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A fresh start lifts the flower back upright the first time it shows.
    if (widget.look.face == Face.hopeful) {
      _bendFrom = _bendOf(Pose.droop);
      _bendAt = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyMotion();
  }

  // iOS Reduce Motion is not part of MediaQueryData, so listen for it too.
  @override
  void didChangeAccessibilityFeatures() => setState(_applyMotion);

  void _applyMotion() {
    _still = reduceMotion(context);
    if (_still) {
      _ticker.stop();
      // Drop any tween in flight: the still flower shows its final look.
      _stageAt = _bendAt = _delightAt = double.negativeInfinity;
    } else if (!_ticker.isActive) {
      _startedAt = _now.value;
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(FlowerView old) {
    super.didUpdateWidget(old);
    if (_still) return;
    final now = _now.value;
    if (widget.look.stage != old.look.stage) {
      _stageFrom = _stage(now, old.look);
      _stageAt = now;
    }
    if (widget.look.pose != old.look.pose) {
      _bendFrom = _bend(now, old.look);
      _bendAt = now;
    }
    if (widget.delightTrigger != old.delightTrigger) {
      _delightAt = now;
    }
  }

  double _tween(double from, double to, double startedAt, double seconds) {
    final t = ((_now.value - startedAt) / seconds).clamp(0.0, 1.0);
    return lerpDouble(from, to, Curves.easeInOut.transform(t))!;
  }

  double _stage(double now, FlowerLook look) =>
      _tween(_stageFrom, look.stage.toDouble(), _stageAt, _growSeconds);

  double _bend(double now, FlowerLook look) =>
      _tween(_bendFrom, _bendOf(look.pose), _bendAt, _bendSeconds);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _now.dispose();
    super.dispose();
  }

  FlowerPainter _painter(double now) {
    final look = widget.look;
    if (_still) {
      return FlowerPainter(
        look: look,
        stage: look.stage.toDouble(),
        bend: _bendOf(look.pose),
      );
    }
    final phase = (widget.seed % 628) / 100;
    // (sway size in radians, seconds per sway)
    final (amp, period) = switch (look.face) {
      Face.asleep || Face.sleepy => (0.0, 1.0),
      Face.sad => (0.008, 9.0),
      Face.worried => (0.02, 9.0),
      Face.curious => (0.03, 6.0),
      Face.hopeful => (0.03, 6.0),
      Face.expectant => (0.035, 6.0),
      Face.content => (0.04, 6.0),
      Face.grin => (0.05, 6.0),
    };
    final blinkEvery = 3.5 + (widget.seed % 20) / 10;
    final sinceBlink = (now + phase) % blinkEvery;
    final d = (now - _delightAt) / _delightSeconds;
    return FlowerPainter(
      look: look,
      stage: _stage(now, look),
      bend: _bend(now, look),
      sway: amp * sin(2 * pi * now / period + phase),
      breathe: look.face == Face.sleepy ? sin(2 * pi * now / 4 + phase) : 0,
      blink: sinceBlink < 0.16 ? sin(pi * sinceBlink / 0.16) : 0,
      gaze: sin(2 * pi * now / 5 + phase),
      delight: d >= 0 && d < 1 ? d : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: ValueListenableBuilder<double>(
          valueListenable: _now,
          builder: (context, now, _) => CustomPaint(painter: _painter(now)),
        ),
      ),
    );
  }
}
