import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/habit_config.dart';
import '../domain/format.dart';
import '../domain/ids.dart';
import '../domain/schedule.dart';
import '../domain/stats.dart';
import '../flower/flower_view.dart';
import '../flower/look.dart';
import '../state/garden_controller.dart';
import 'charts.dart';
import 'history.dart';
import 'theme.dart';
import 'toast.dart';
import 'value_dialog.dart';

/// "37 days · 1 grace used", "Habit formed ✓", or a gentle nudge.
String statusLine(Tracked t, Stats s) {
  final weekly = t.config.schedule.kind == ScheduleKind.timesPerWeek;
  final unit = weekly ? 'week' : 'day';
  final grace = s.graceUsed > 0 ? ' · ${s.graceUsed} grace used' : '';
  final streak = s.streak > 0
      ? '${s.streak} $unit${s.streak == 1 ? '' : 's'}$grace'
      : null;
  if (s.formed) {
    return streak == null ? 'Habit formed ✓' : 'Habit formed ✓ · $streak';
  }
  if (streak != null) return streak;
  return s.totalCompletions == 0 ? 'Ready when you are' : 'Start a new streak';
}

/// Today's progress for a number habit ("3 of 8 glasses today"); null for
/// yes/no habits.
String? progressLine(Tracked t, int today) {
  final c = t.config;
  if (c.isYesNo) return null;
  final unit = c.unit.isEmpty ? '' : ' ${c.unit}';
  final v = formatNum(t.log[today] ?? 0);
  final target = formatNum(c.goal.target);
  return c.goal.atMost
      ? '$v of $target$unit max today'
      : '$v of $target$unit today';
}

/// What a tap on the card's button means, for screen readers.
String logLabel(Tracked t, int today) {
  final c = t.config;
  final v = t.log[today];
  if (c.isYesNo) return v == null ? 'Mark ${c.name} done' : 'Undo ${c.name}';
  final target = '${formatNum(c.goal.target)} ${c.unit}'.trim();
  return 'Add one to ${c.name}, ${formatNum(v ?? 0)} of $target today';
}

/// Logs today for [t] (the quick tap), with a gentle message if saving fails.
Future<void> logToday(BuildContext context, WidgetRef ref, String id) async {
  try {
    await ref.read(gardenProvider.notifier).tap(id);
  } catch (_) {
    if (context.mounted) showToast(context, retryText);
  }
}

/// Opens the exact-value box for [day] and saves the answer.
Future<void> editDay(
  BuildContext context,
  WidgetRef ref,
  Tracked t,
  int day,
) async {
  final c = t.config;
  final r = await askValue(
    context,
    title: '${c.name}, ${shortDate(day)}',
    unit: c.unit,
    current: t.log[day],
  );
  if (r == null || !context.mounted) return;
  try {
    await ref.read(gardenProvider.notifier).setValue(c.id, day, r.value);
  } catch (_) {
    if (context.mounted) showToast(context, retryText);
  }
}

class HabitCard extends ConsumerWidget {
  const HabitCard({super.key, required this.habit, required this.onOpen});

  final Tracked habit;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final c = habit.config;
    final s = habit.stats(today);
    final color = flowerColor(c.flowerId, Theme.of(context).brightness);
    final v = habit.log[today];
    final done = v != null && c.goal.met(v);
    final look = lookOf(c.flowerId, s, doneToday: done);
    final theme = Theme.of(context);
    return Card(
      color: accentWash(color, theme.brightness),
      child: InkWell(
        key: Key('card-${c.id}'),
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LogButton(
                key: Key('log-${c.id}'),
                habit: habit,
                today: today,
                color: color,
                done: done,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      statusLine(habit, s),
                      maxLines: 2,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (progressLine(habit, today) case final p?)
                      Text(
                        p,
                        key: Key('progress-${c.id}'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 10),
                    HeatStrip(
                      marks: marksOf(habit, s),
                      today: today,
                      createdDay: c.createdDay,
                      color: color,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              ExcludeSemantics(
                child: FlowerView(
                  look: look,
                  size: 60,
                  seed: stableHash(c.id),
                  delightTrigger: (v ?? 0).round(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tap: done / +1. Long press: type an exact value.
class _LogButton extends ConsumerWidget {
  const _LogButton({
    super.key,
    required this.habit,
    required this.today,
    required this.color,
    required this.done,
  });

  final Tracked habit;
  final int today;
  final Color color;
  final bool done;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = habit.config;
    final v = habit.log[today] ?? 0;
    final onColor = onAccent(color);
    final idle = Theme.of(context).colorScheme.surfaceContainerLowest;
    return Semantics(
      button: true,
      label: logLabel(habit, today),
      onTap: () => logToday(context, ref, c.id),
      onLongPress: () => editDay(context, ref, habit, today),
      excludeSemantics: true,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Material(
          color: done ? color : idle,
          shape: CircleBorder(side: BorderSide(color: color, width: 2)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => logToday(context, ref, c.id),
            onLongPress: () => editDay(context, ref, habit, today),
            child: Center(
              child: c.isYesNo
                  ? Icon(
                      done ? Icons.check : Icons.add,
                      color: done ? onColor : color,
                    )
                  // Large text: mid-tone accents only reach ~4:1.
                  : Padding(
                      padding: const EdgeInsets.all(6),
                      child: FittedBox(
                        child: Text(
                          formatNum(v),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            // Pale accents fail on white, so the open count
                            // uses ink and the ring carries the colour.
                            color: done
                                ? onColor
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty garden: a seed and one call to action.
class EmptyHome extends StatelessWidget {
  const EmptyHome({super.key, required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FlowerView(
            look: FlowerLook(kind: 'daisy', stage: 0, face: Face.sleepy),
            size: 120,
          ),
          const SizedBox(height: 16),
          Text(
            'Your habits, growing daily',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a habit and tick it off each day. Your flower grows with you.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('add-first'),
            onPressed: onAdd,
            child: const Text('Add your first habit'),
          ),
        ],
      ),
    ),
  );
}
