import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/garden_controller.dart';
import '../purchases/purchases.dart';
import 'analytics_card.dart';
import 'habit_card.dart';
import 'paywall.dart';
import 'settings_screen.dart';

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
    final theme = Theme.of(context);
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
        bottom: habits.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$done of ${done + open} done today',
                      key: const Key('today-summary'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                const AnalyticsAskCard(),
                for (final h in habits) ...[
                  HabitCard(
                    key: ValueKey(h.config.id),
                    habit: h,
                    onOpen: () => onOpen(h.config.id),
                  ),
                  const SizedBox(height: 12),
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
