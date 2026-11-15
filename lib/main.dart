import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics/analytics.dart';
import 'app.dart';
import 'demo/demo.dart';
import 'domain/day.dart';
import 'notify/notification_sync.dart';
import 'notify/scheduler.dart';
import 'purchases/purchases.dart';
import 'state/garden_controller.dart';
import 'widget/widget_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final db = await openGardenDb();
  if (demoMode) await db.replaceAll(demoHabits(dayIndex(DateTime.now())));
  final habits = await db.loadAll();
  HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
  final prefs = await SharedPreferences.getInstance();
  NotificationScheduler scheduler = const NoopScheduler();
  try {
    final local = LocalNotificationScheduler();
    await local.initialize();
    scheduler = local;
  } catch (e) {
    debugPrint('Notifications unavailable: $e');
  }
  runApp(
    ProviderScope(
      overrides: [
        gardenDbProvider.overrideWithValue(db),
        initialHabitsProvider.overrideWithValue(habits),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        if (demoMode)
          purchasesProvider.overrideWithValue(const DemoPurchases()),
        // shortcut: no analytics backend chosen yet, so events go nowhere; swap
        // NoopSink for the real one when it is.
        analyticsProvider.overrideWithValue(Analytics(prefs, const NoopSink())),
      ],
      child: const GardenApp(),
    ),
  );
}
