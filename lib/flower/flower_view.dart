import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../ui/motion.dart';
import 'look.dart';

const _growSeconds = 0.6;
const _delightSeconds = 0.9;

/// How far a drooping plant leans, in radians.
double _leanOf(Pose p) => switch (p) {
  Pose.upright => 0,
  Pose.droop => 0.12,
  Pose.slump => 0.24,
};

String assetOf(FlowerLook look, [int? stage]) =>
    'assets/plants/${look.kind}_${stage ?? look.stage}.png';

/// A live plant: sways, leans when neglected, hops when watered and fades
/// between growth stages. With reduced motion it stands still and only its
/// picture changes.
class FlowerView extends StatefulWidget {
  const FlowerView({
    super.key,
    required this.look,
    required this.size,
    this.seed = 0,
    this.delightTrigger = 0,
  });

  final FlowerLook look;

  /// Width and height in logical pixels; the plant stands on the bottom.
  final double size;

  /// Offsets the sway so neighbours do not move in step.
  final int seed;

  /// Each change plays the just-watered hop.
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

  late int _fromStage = widget.look.stage;
  double _stageAt = double.negativeInfinity;
  double _delightAt = double.negativeInfinity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      // Drop any tween in flight: the still plant shows its final look.
      _stageAt = _delightAt = double.negativeInfinity;
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
      _fromStage = old.look.stage;
      _stageAt = now;
    }
    if (widget.delightTrigger != old.delightTrigger) _delightAt = now;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _now.dispose();
    super.dispose();
  }

  Widget _picture(String asset, double dpr) => Image.asset(
    asset,
    width: widget.size,
    height: widget.size,
    fit: BoxFit.contain,
    cacheWidth: (widget.size * dpr).ceil().clamp(1, 384),
    filterQuality: FilterQuality.medium,
    gaplessPlayback: true,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) => SizedBox.square(dimension: widget.size),
  );

  Widget _frame(double now, double dpr) {
    final look = widget.look;
    final fade = ((now - _stageAt) / _growSeconds).clamp(0.0, 1.0);
    Widget picture = _picture(assetOf(look), dpr);
    if (fade < 1) {
      picture = Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Opacity(
            opacity: 1 - Curves.easeInOut.transform(fade),
            child: _picture(assetOf(look, _fromStage), dpr),
          ),
          Opacity(opacity: Curves.easeInOut.transform(fade), child: picture),
        ],
      );
    }
    if (_still) return picture;
    // (sway size in radians, seconds per sway)
    final (amp, period) = switch (look.face) {
      Face.asleep || Face.sleepy => (0.004, 8.0),
      Face.sad => (0.008, 9.0),
      Face.worried => (0.015, 9.0),
      Face.curious || Face.hopeful => (0.025, 6.0),
      Face.expectant => (0.03, 6.0),
      Face.content => (0.035, 6.0),
      Face.grin => (0.04, 6.0),
    };
    final phase = (widget.seed % 628) / 100;
    final d = (now - _delightAt) / _delightSeconds;
    final hop = d >= 0 && d < 1 ? sin(pi * d) : 0.0;
    return Transform.translate(
      offset: Offset(0, -hop * widget.size * 0.06),
      child: Transform.rotate(
        angle: _leanOf(look.pose) + amp * sin(2 * pi * now / period + phase),
        alignment: Alignment.bottomCenter,
        child: Transform.scale(
          scale: lerpDouble(1, 1.08, hop)!,
          alignment: Alignment.bottomCenter,
          child: picture,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final size = widget.size;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned.fill(
              child: ValueListenableBuilder<double>(
                valueListenable: _now,
                builder: (context, now, _) => _frame(now, dpr),
              ),
            ),
            if (widget.look.bubble)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: size * 0.28,
                  height: size * 0.28,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD6ECF7),
                    shape: BoxShape.circle,
                  ),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Icon(
                      Icons.water_drop,
                      size: size * 0.17,
                      color: const Color(0xFF3B8EC0),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
