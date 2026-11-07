import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../art/art_pack.dart';
import '../domain/growth.dart';
import '../domain/habit.dart';
import '../domain/messages.dart';
import '../domain/rules.dart';
import '../state/art_provider.dart';
import '../state/banner_provider.dart';
import '../state/garden_controller.dart';
import 'meadow_painter.dart';
import 'theme.dart';

class MeadowScreen extends ConsumerStatefulWidget {
  const MeadowScreen({
    super.key,
    required this.onOpenHabit,
    required this.onPlant,
  });
  final void Function(String habitId) onOpenHabit;
  final VoidCallback onPlant;

  @override
  ConsumerState<MeadowScreen> createState() => _MeadowScreenState();
}

class _MeadowScreenState extends ConsumerState<MeadowScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // One 24s loop; sway uses 4 cycles of it, insects 1 or 2, so all loop smoothly.
  late final _t = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );
  bool _still = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.of(context).disableAnimations;
    if (_still) {
      _t.stop();
    } else if (!_t.isAnimating) {
      _t.repeat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(gardenProvider.notifier).refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _t.dispose();
    super.dispose();
  }

  void _plant(int count) {
    if (count >= Rules.habitCap) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              "Your garden is full for now. You can remove a flower you've "
              'finished with to make room.',
            ),
          ),
        );
    } else {
      widget.onPlant();
    }
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(gardenProvider);
    final art = ref.watch(artPackProvider);
    final dismissed = ref.watch(bannerDismissedProvider);
    final today = ref.read(todayProvider)();
    // freshStart is the only tone that names a habit.
    final choice = bannerChoice(habits, today);
    final width = max(
      MediaQuery.sizeOf(context).width,
      150.0 * (habits.length + 1),
    );
    return Scaffold(
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final height = box.maxHeight;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: AnimatedBuilder(
                    animation: _t,
                    builder: (context, _) => Stack(
                      children: [
                        const Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(painter: MeadowPainter()),
                          ),
                        ),
                        if (!_still) ..._insects(width, height),
                        for (var i = 0; i < habits.length; i++)
                          _flower(habits[i], i, art, width, height),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (habits.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Your meadow is waiting. Plant your first seed.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
          if (showsBanner(habits, today) &&
              !bannerHidden(dismissed, bannerKey(choice.habitId)))
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _banner(choice, today),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: SafeArea(
              child: Center(
                child: FilledButton(
                  key: const Key('plant-button'),
                  onPressed: () => _plant(habits.length),
                  child: const Text('Plant a seed'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(
    ({Tone tone, String? habitId, String? flower}) choice,
    int today,
  ) {
    final text = encouragement(
      choice.tone,
      bannerSeed(choice.tone, today),
      flower: choice.flower,
    );
    final id = choice.habitId;
    void dismiss() =>
        ref.read(bannerDismissedProvider.notifier).dismiss(bannerKey(id));
    Widget message = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
    if (id != null) {
      message = Semantics(
        label: text,
        button: true,
        onTap: () => widget.onOpenHabit(id),
        excludeSemantics: true,
        child: InkWell(onTap: () => widget.onOpenHabit(id), child: message),
      );
    }
    return Material(
      key: const Key('encouragement-banner'),
      color: skyMist,
      elevation: 1,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(child: message),
          Semantics(
            label: 'Dismiss message',
            button: true,
            onTap: dismiss,
            excludeSemantics: true,
            child: InkWell(
              key: const Key('dismiss-banner'),
              onTap: dismiss,
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.close, size: 20, color: inkBrown),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _flower(Habit h, int i, ArtPack art, double w, double hgt) {
    final base = flowerPosition(h.id, i, w, hgt);
    final stage = growthStage(h);
    final size = 56.0 + stage * 20;
    final frames = art.framesFor(h.flowerId, stage, healthOf(h));
    final phase = (stableHash(h.id) % 628) / 100;
    final angle = _still ? 0.0 : 0.05 * sin(2 * pi * _t.value * 4 + phase);
    Widget image = frames.isEmpty
        ? SizedBox(width: size, height: size)
        : Image.asset(
            frames.first,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
          );
    image = Transform.rotate(
      angle: angle,
      alignment: Alignment.bottomCenter,
      child: image,
    );
    // A lost habit stays tappable as a faded seed patch.
    if (h.lost) image = Opacity(opacity: 0.45, child: image);
    return Positioned(
      left: base.dx - 60,
      top: base.dy - size,
      width: 120,
      child: GestureDetector(
        key: ValueKey('flower-${h.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onOpenHabit(h.id),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            image,
            Text(
              h.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _insects(double w, double hgt) {
    // (bee?, cycles per loop, phase, base y fraction)
    const specs = [
      (true, 1, 0.0, 0.25),
      (true, 2, 0.5, 0.4),
      (false, 1, 0.3, 0.15),
      (false, 2, 0.8, 0.32),
    ];
    return [
      for (final (bee, k, ph, fy) in specs)
        Positioned(
          left: w * (0.5 + 0.45 * sin(2 * pi * (_t.value * k + ph))) - 12,
          top: hgt * fy + 18 * sin(2 * pi * (_t.value * (k + 2) + ph)),
          child: IgnorePointer(
            child: CustomPaint(
              key: const Key('insect'),
              size: const Size(24, 24),
              painter: InsectPainter(
                bee: bee,
                flap: (sin(2 * pi * _t.value * 24 * 4) + 1) / 2,
              ),
            ),
          ),
        ),
    ];
  }
}
