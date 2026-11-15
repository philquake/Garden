import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'analytics/analytics.dart';
import 'app.dart';
import 'data/garden_db.dart';
import 'notify/notification_sync.dart';
import 'notify/scheduler.dart';
import 'state/garden_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final db = await GardenDb.open(
    databaseFactory,
    p.join(await getDatabasesPath(), 'garden.db'),
  );
  final habits = await db.loadAll();
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
        // shortcut: no analytics backend chosen yet, so events go nowhere; swap
        // NoopSink for the real one when it is.
        analyticsProvider.overrideWithValue(Analytics(prefs, const NoopSink())),
      ],
      child: const GardenApp(),
    ),
  );
}
