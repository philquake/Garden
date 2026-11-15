import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics/analytics.dart';
import 'notify/notification_sync.dart';
import 'state/garden_controller.dart';
import 'ui/habit_form.dart';
import 'ui/habit_screen.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

class GardenApp extends ConsumerStatefulWidget {
  const GardenApp({super.key});

  @override
  ConsumerState<GardenApp> createState() => _GardenAppState();
}

class _GardenAppState extends ConsumerState<GardenApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(analyticsProvider).appOpened(ref.read(todayProvider));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The day may have changed while we were away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(todayProvider.notifier).refresh();
      ref.read(analyticsProvider).appOpened(ref.read(todayProvider));
      ref.read(notificationSyncProvider).replan();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(notificationSyncProvider);
    return MaterialApp(
      theme: gardenTheme(Brightness.light),
      darkTheme: gardenTheme(Brightness.dark),
      debugShowCheckedModeBanner: false,
      title: 'Garden',
      home: Builder(
        // The navigator sits below the MaterialApp, so push via this context.
        builder: (context) {
          void push(Widget w) =>
              Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => w));
          return HomeScreen(
            onAdd: () => push(const HabitForm()),
            onOpen: (id) => push(HabitScreen(habitId: id)),
          );
        },
      ),
    );
  }
}
