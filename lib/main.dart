import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/habit_store.dart';
import 'notify/notification_sync.dart';
import 'notify/scheduler.dart';
import 'state/garden_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
        habitStoreProvider.overrideWithValue(HabitStore(prefs)),
        notificationSchedulerProvider.overrideWithValue(scheduler),
      ],
      child: const GardenApp(),
    ),
  );
}
