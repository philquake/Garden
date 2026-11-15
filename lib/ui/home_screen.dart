import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/day.dart';
import '../state/garden_controller.dart';
import '../purchases/purchases.dart';
import 'analytics_card.dart';
import 'habit_card.dart';
import 'history.dart';
import 'paywall.dart';
import 'settings_screen.dart';
import 'theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onAdd, required this.onOpen});

  final VoidCallback onAdd;
  final void Function(String id) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(gardenProvider);
    final today = ref.watch(todayProvider);
    var open = 0;
    var done = 0;
    for (final t in habits) {
      final v = t.log[today];
      if (v != null && t.config.goal.met(v)) {
        done++;
      } else if (t.stats(today).due) {
        open++;
      }
    }
    final unlocked = ref.watch(unlockedProvider);
    // The unlock is offered when the 4th habit is asked for, never earlier.
    void add() => !unlocked && habits.length >= freeHabitLimit
        ? showPaywall(context, ref)
        : onAdd();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Garden'),
        actions: [
          IconButton(
            key: const Key('open-settings'),
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: habits.isEmpty
          ? Column(
              children: [
                Expanded(child: EmptyHome(onAdd: add)),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: AnalyticsAskCard(),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                _TodayCard(today: today, done: done, total: done + open),
                const AnalyticsAskCard(),
                for (final h in habits) ...[
                  HabitCard(
                    key: ValueKey(h.config.id),
                    habit: h,
                    onOpen: () => onOpen(h.config.id),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
      floatingActionButton: habits.isEmpty
          ? null
          : FloatingActionButton.extended(
              key: const Key('add-habit'),
              onPressed: add,
              icon: const Icon(Icons.add),
              label: const Text('Add habit'),
            ),
    );
  }
}

/// Date, how many of today's habits are done, and a calm progress bar.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.today,
    required this.done,
    required this.total,
  });
  final int today;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = dateOf(today);
    final all = total > 0 && done == total;
    return SectionCard(
      color: theme.colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${dayNames[d.weekday - 1]}, ${d.day} ${monthNames[d.month - 1]}',
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$done of $total done today',
                  key: const Key('today-summary'),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (all)
                Icon(Icons.spa_outlined, color: theme.colorScheme.primary),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerLowest,
            ),
          ),
        ],
      ),
    );
  }
}
