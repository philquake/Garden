import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../art/art_pack.dart';
import '../domain/day.dart';
import '../domain/growth.dart';
import '../domain/habit.dart';
import '../domain/neglect.dart';
import '../domain/rules.dart';
import '../domain/schedule.dart';
import '../domain/week_progress.dart';
import '../state/art_provider.dart';
import '../state/garden_controller.dart';
import '../state/water_random_provider.dart';
import 'theme.dart';
import 'water_effect.dart';

class HabitScreen extends ConsumerStatefulWidget {
  const HabitScreen({super.key, required this.habitId, required this.onEdit});
  final String habitId;
  final VoidCallback onEdit;

  @override
  ConsumerState<HabitScreen> createState() => _HabitScreenState();
}

class _HabitScreenState extends ConsumerState<HabitScreen> {
  int _waterTaps = 0;

  /// Runs [action]; on any failure refreshes the garden and says so gently.
  /// Returns whether it succeeded.
  Future<bool> _attempt(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (_) {
      // Fall through to the gentle recovery below.
    }
    if (!mounted) return false;
    try {
      await ref.read(gardenProvider.notifier).refresh();
    } catch (_) {}
    if (!mounted) return false;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            "That didn't go through. Your garden has been refreshed, "
            'so please try again.',
          ),
        ),
      );
    return false;
  }

  Future<void> _water(Habit h) async {
    if (h.lost) return;
    final ok = await _attempt(
      () => ref.read(gardenProvider.notifier).water(h.id),
    );
    if (ok && mounted) setState(() => _waterTaps++);
  }

  Future<void> _backfill(Habit h, int day) => _attempt(
    () => ref.read(gardenProvider.notifier).water(h.id, forDay: day),
  );

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(gardenProvider);
    final h = habits.where((e) => e.id == widget.habitId).firstOrNull;
    if (h == null) return _missing(context);
    final today = ref.read(todayProvider)();
    final art = ref.watch(artPackProvider);
    final notifier = ref.read(gardenProvider.notifier);
    final theme = Theme.of(context);
    final progress = weekProgress(h, today);
    final waiting = isWaiting(h, today);
    final freshStart = canFreshStart(h, today)
        ? [
            FilledButton(
              key: const Key('fresh-start-button'),
              onPressed: () => _attempt(() => notifier.freshStart(h.id)),
              child: const Text('Give it a fresh start'),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your flower comes back at the stage it had reached. '
              'Your history stays.',
            ),
          ]
        : const <Widget>[];
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [skyBlue, skyMist, sageLight],
                ),
              ),
              child: SafeArea(
                child: Stack(
                  children: [
                    Center(
                      child: Semantics(
                        button: !h.lost,
                        label: h.lost
                            ? '${h.name} is resting. You can plant a new seed '
                                  'below.'
                            : 'Water ${h.name}',
                        onTap: h.lost ? null : () => _water(h),
                        excludeSemantics: true,
                        child: GestureDetector(
                          key: const Key('habit-flower'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _water(h),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: WaterEffect(
                              trigger: _waterTaps,
                              random: ref.read(waterRandomProvider),
                              child: _flower(h, art),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Semantics(
                        button: true,
                        label: 'Back',
                        excludeSemantics: true,
                        onTap: () => Navigator.of(context).maybePop(),
                        child: IconButton(
                          key: const Key('habit-back-button'),
                          tooltip: 'Back',
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.name, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(_scheduleWords(h.schedule)),
                  const SizedBox(height: 4),
                  Semantics(
                    label:
                        '${progress.done} of ${progress.expected} '
                        'waterings this week',
                    excludeSemantics: true,
                    child: Text(
                      '${progress.done} of ${progress.expected} this week',
                      key: const Key('week-progress'),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (h.reminderMinutes >= 0 &&
                      h.ignoredReminders >= 3 &&
                      !h.lost) ...[
                    const SizedBox(height: 12),
                    _PausedCard(onChange: widget.onEdit),
                  ],
                  if (waiting) ...[
                    const SizedBox(height: 12),
                    _WaitingCard(
                      flower: h.flowerId.toLowerCase(),
                      later: daysSinceWater(h, today) >= Rules.warnDays[1],
                      children: freshStart,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _Calendar(
                    habit: h,
                    today: today,
                    onBackfill: (d) => _backfill(h, d),
                  ),
                  const SizedBox(height: 16),
                  if (h.lost) ...[
                    FilledButton(
                      key: const Key('replant-button'),
                      onPressed: () => _attempt(() => notifier.replant(h.id)),
                      child: const Text('Plant a new seed'),
                    ),
                    const SizedBox(height: 4),
                    const Text('Your history stays exactly as it is.'),
                  ] else if (!waiting)
                    ...freshStart,
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('edit-button'),
                    onPressed: widget.onEdit,
                    child: const Text('Edit'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _missing(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This flower is no longer in your garden.'),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('back-button'),
              onPressed: () => Navigator.maybePop(context),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _flower(Habit h, ArtPack art) {
    final stage = h.lost ? 0 : growthStage(h);
    final frames = art.framesFor(h.flowerId, stage, healthOf(h));
    const size = 240.0;
    Widget image = frames.isEmpty
        ? const SizedBox(width: size, height: size)
        : Image.asset(
            frames.first,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const SizedBox(width: size, height: size),
          );
    if (h.lost) image = Opacity(opacity: 0.45, child: image);
    return image;
  }
}

class _PausedCard extends StatelessWidget {
  const _PausedCard({required this.onChange});
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('reminders-paused-card'),
      color: sageLight,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reminders are paused for now. Want to pick a gentler time?',
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('change-reminder-button'),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: onChange,
              child: const Text('Change reminder'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gentle note from day 14 without water, holding the fresh-start button.
class _WaitingCard extends StatelessWidget {
  const _WaitingCard({
    required this.flower,
    required this.later,
    required this.children,
  });
  final String flower;
  final bool later;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = later
        ? 'There is still time. Your $flower is waiting for you, and a little '
              'water helps. A fresh start is here whenever you like. '
              'Your history stays.'
        : 'Your $flower is waiting for you. A little water helps, or give it '
              'a fresh start whenever you like. Your history stays.';
    return Card(
      key: const Key('loss-warning-card'),
      color: skyMist,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(text), const SizedBox(height: 8), ...children],
        ),
      ),
    );
  }
}

const _dayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _scheduleWords(Schedule s) => switch (s.kind) {
  ScheduleKind.daily => 'Every day',
  ScheduleKind.timesPerWeek =>
    s.value == 1 ? 'Once a week' : '${s.value} times a week',
  ScheduleKind.weekday => 'Every ${_dayNames[s.value - 1]}',
};

class _Calendar extends StatelessWidget {
  const _Calendar({
    required this.habit,
    required this.today,
    required this.onBackfill,
  });
  final Habit habit;
  final int today;
  final void Function(int day) onBackfill;

  @override
  Widget build(BuildContext context) {
    final start = today - (weekdayOf(today) - 1) - 28;
    const initials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      key: const Key('habit-calendar'),
      children: [
        Semantics(
          label: 'Calendar, weeks start on Monday',
          excludeSemantics: true,
          child: Row(
            children: [
              for (final i in initials)
                Expanded(
                  child: Center(
                    child: Text(
                      i,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (var r = 0; r < 5; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(child: _cell(start + r * 7 + c)),
            ],
          ),
      ],
    );
  }

  Widget _cell(int d) {
    final watered = habit.wateredDays.contains(d);
    final dim = d > today || d < habit.plantedDay;
    final canBackfill =
        !habit.lost &&
        !watered &&
        d < today &&
        d >= today - Rules.backfillDays &&
        d >= habit.plantedDay;
    final date = DateTime.utc(1970).add(Duration(days: d));
    Widget cell = Container(
      key: ValueKey('cell-$d'),
      height: 44,
      margin: const EdgeInsets.all(2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: watered ? dustyPink : null,
        border: d == today
            ? Border.all(color: sageDeep, width: 2)
            : canBackfill
            ? Border.all(color: sage)
            : null,
      ),
      child: Text(
        '${date.day}',
        key: watered ? ValueKey('watered-$d') : null,
        style: TextStyle(
          color: inkBrown.withValues(alpha: dim ? 0.3 : 1),
          fontSize: 12,
        ),
      ),
    );
    final label =
        '${_dayNames[weekdayOf(d) - 1]}, ${date.day} '
        '${_monthNames[date.month - 1]}';
    if (canBackfill) {
      cell = Semantics(
        button: true,
        label: 'Mark $label as watered',
        excludeSemantics: true,
        onTap: () => onBackfill(d),
        child: GestureDetector(
          key: ValueKey('backfill-$d'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onBackfill(d),
          child: cell,
        ),
      );
    } else {
      cell = Semantics(
        label: watered ? '$label, watered' : label,
        excludeSemantics: true,
        child: cell,
      );
    }
    return cell;
  }
}
