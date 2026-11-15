import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/day.dart';

import '../domain/habit_config.dart';
import '../domain/ids.dart';
import '../domain/schedule.dart';
import '../domain/stats.dart';
import '../flower/flower_view.dart';
import '../flower/look.dart';
import '../state/garden_controller.dart';
import 'charts.dart';
import 'habit_card.dart';
import 'habit_form.dart';
import 'history.dart';
import 'paywall.dart';
import '../purchases/purchases.dart';
import 'theme.dart';
import 'toast.dart';

String _change(double d) {
  final p = (d * 100).round();
  return '${p > 0 ? '+' : ''}$p%';
}

class HabitScreen extends ConsumerStatefulWidget {
  const HabitScreen({super.key, required this.habitId});
  final String habitId;

  @override
  ConsumerState<HabitScreen> createState() => _HabitScreenState();
}

class _HabitScreenState extends ConsumerState<HabitScreen> {
  Range _range = Range.month;

  @override
  Widget build(BuildContext context) {
    final t = ref
        .watch(gardenProvider)
        .where((e) => e.config.id == widget.habitId)
        .firstOrNull;
    // Removed from under us: the form pops to the first route, this is a guard.
    if (t == null) return const Scaffold();
    final today = ref.watch(todayProvider);
    final c = t.config;
    final s = t.stats(today);
    final theme = Theme.of(context);
    final color = flowerColor(c.flowerId, theme.brightness);
    final weekly = c.schedule.kind == ScheduleKind.timesPerWeek;
    final unit = weekly ? 'weeks' : 'days';
    final b = buckets(t, today, _range);
    final v = t.log[today];
    final look = lookOf(c.flowerId, s, doneToday: v != null && c.goal.met(v));
    final score = s.score;
    final unlocked = ref.watch(unlockedProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(c.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            key: const Key('edit-habit'),
            tooltip: 'Edit habit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => HabitForm(existing: c)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SectionCard(
            color: accentWash(color, theme.brightness),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: FlowerView(
                    look: look,
                    size: 110,
                    seed: stableHash(c.id),
                    delightTrigger: (v ?? 0).round(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusLine(t, s),
                        key: const Key('status-line'),
                        style: theme.textTheme.titleMedium,
                      ),
                      if (progressLine(t, today) case final p?)
                        Text(p, key: const Key('progress-line')),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: s.growth,
                          minHeight: 8,
                          color: color,
                          backgroundColor: color.withValues(alpha: 0.18),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.formed
                            ? 'Habit formed after $formedAfter days'
                            : '${s.qualifyingDays} of $formedAfter days to '
                                  'habit formed',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Overview',
            child: Row(
              children: [
                ScoreRing(score: score, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: _Figure(
                    _change(score - scoreAt(t, today - 30)),
                    'Month',
                    key: const Key('change-month'),
                  ),
                ),
                Expanded(
                  child: _Figure(
                    _change(score - scoreAt(t, today - 365)),
                    'Year',
                    key: const Key('change-year'),
                  ),
                ),
                Expanded(
                  child: _Figure(
                    '${s.totalCompletions}',
                    'Total',
                    key: const Key('total'),
                  ),
                ),
              ],
            ),
          ),
          if (unlocked) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SegmentedButton<Range>(
                key: const Key('range'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: Range.week, label: Text('Week')),
                  ButtonSegment(value: Range.month, label: Text('Month')),
                  ButtonSegment(value: Range.year, label: Text('Year')),
                ],
                selected: {_range},
                onSelectionChanged: (r) => setState(() => _range = r.first),
              ),
            ),
            _Section(
              title: 'Score',
              child: ScoreLine(buckets: b, range: _range, color: color),
            ),
            _Section(
              title: 'History',
              child: HistoryBars(buckets: b, range: _range, color: color),
            ),
          ] else ...const [
            LockedCard(
              title: 'Score and history',
              what: 'See your score over time and how many days you did it, by week, month or year.',
            ),
          ],
          _Section(
            title: 'Calendar',
            child: _MonthCalendar(
              habit: t,
              stats: s,
              today: today,
              color: color,
              unlocked: unlocked,
            ),
          ),
          if (unlocked)
            _Section(
              title: 'Best streaks',
              child: s.bestRuns.isEmpty
                  ? const Text('Your first streak starts with one day.')
                  : Column(
                      children: [
                        for (final r in s.bestRuns)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${r.length} ${r.length == 1 ? unit.substring(0, unit.length - 1) : unit}',
                            ),
                            trailing: Text('from ${shortDate(r.start)}'),
                          ),
                      ],
                    ),
            )
          else
            const LockedCard(
              title: 'Best streaks',
              what: 'Your longest runs, with when each one started.',
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({this.title, required this.child});
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) => SectionCard(title: title, child: child);
}

class _Figure extends StatelessWidget {
  const _Figure(this.value, this.label, {super.key});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$label $value',
    excludeSemantics: true,
    child: Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

/// One month at a time; tap a day to log or fix it.
class _MonthCalendar extends ConsumerStatefulWidget {
  const _MonthCalendar({
    required this.habit,
    required this.stats,
    required this.today,
    required this.color,
    required this.unlocked,
  });

  final Tracked habit;
  final Stats stats;
  final bool unlocked;
  final int today;
  final Color color;

  @override
  ConsumerState<_MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends ConsumerState<_MonthCalendar> {
  int _back = 0; // months before the current one

  Future<void> _tap(int day) async {
    final t = widget.habit;
    if (t.config.isYesNo) {
      try {
        await ref
            .read(gardenProvider.notifier)
            .setValue(t.config.id, day, t.log.containsKey(day) ? null : 1);
      } catch (_) {
        if (mounted) showToast(context, retryText);
      }
    } else {
      await editDay(context, ref, t, day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.habit;
    final cur = dateOf(widget.today);
    final first = DateTime.utc(cur.year, cur.month - _back, 1);
    final firstDay = monthStartDay(first.year, first.month);
    final daysIn = DateTime.utc(first.year, first.month + 1, 0).day;
    final lead = first.weekday - 1;
    final created = dateOf(t.config.createdDay);
    final canGoBack =
        DateTime.utc(
          first.year,
          first.month - 1,
          1,
        ).isAfter(DateTime.utc(created.year, created.month, 1)) ||
        DateTime.utc(
          first.year,
          first.month - 1,
          1,
        ).isAtSameMomentAs(DateTime.utc(created.year, created.month, 1));
    final marks = marksOf(t, widget.stats);
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              key: const Key('month-prev'),
              tooltip: 'Previous month',
              onPressed: !canGoBack
                  ? null
                  : widget.unlocked
                  ? () => setState(() => _back++)
                  : () => showPaywall(context, ref),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${monthNames[first.month - 1]} ${first.year}',
              key: const Key('month-title'),
              style: theme.textTheme.titleMedium,
            ),
            IconButton(
              key: const Key('month-next'),
              tooltip: 'Next month',
              onPressed: _back > 0 ? () => setState(() => _back--) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          children: [
            for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(child: Text(d, style: theme.textTheme.bodySmall)),
              ),
          ],
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
            for (var n = 1; n <= daysIn; n++)
              _cell(firstDay + n - 1, n, marks[firstDay + n - 1], theme),
          ],
        ),
      ],
    );
  }

  Widget _cell(int day, int n, Mark? mark, ThemeData theme) {
    final enabled =
        day >= widget.habit.config.createdDay && day <= widget.today;
    final color = widget.color;
    final fill = switch (mark) {
      Mark.met => color,
      Mark.partial => color.withValues(alpha: 0.4),
      _ => Colors.transparent,
    };
    final text = mark == Mark.met ? onAccent(color) : null;
    final state = switch (mark) {
      Mark.met => 'done',
      Mark.partial => 'partly done',
      Mark.forgiven => 'forgiven',
      _ => 'not done',
    };
    return Semantics(
      button: enabled,
      enabled: enabled,
      label: '${shortDate(day)}, ${enabled ? state : 'not available'}',
      excludeSemantics: true,
      onTap: enabled ? () => _tap(day) : null,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: InkWell(
          key: Key('day-$day'),
          customBorder: const CircleBorder(),
          onTap: enabled ? () => _tap(day) : null,
          child: Ink(
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: mark == Mark.forgiven
                  ? Border.all(color: color, width: 2)
                  : null,
            ),
            child: Center(
              child: Text(
                '$n',
                style:
                    // Done days are large bold text: mid-tone accents only
                    // reach ~4:1 with either ink.
                    TextStyle(
                      color: text,
                      fontSize: mark == Mark.met ? 18 : null,
                      fontWeight: day == widget.today || mark == Mark.met
                          ? FontWeight.w700
                          : null,
                    ).copyWith(
                      color: enabled
                          ? text
                          : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
