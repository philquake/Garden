import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'art/art_pack.dart';
import 'data/habit_store.dart';
import 'notify/notification_sync.dart';
import 'notify/scheduler.dart';
import 'state/art_provider.dart';
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
  // To switch packs, change 'watercolour' and list assets/art/<pack>/ in
  // pubspec.yaml (see docs/art-pack.md). Any failure keeps the placeholder art.
  ArtPack art;
  try {
    art = await ArtPack.load(rootBundle, pack: 'watercolour');
  } catch (e) {
    art = ArtPack.placeholder();
  }
  runApp(
    ProviderScope(
      overrides: [
        habitStoreProvider.overrideWithValue(HabitStore(prefs)),
        artPackProvider.overrideWithValue(art),
        notificationSchedulerProvider.overrideWithValue(scheduler),
      ],
      child: const GardenApp(),
    ),
  );
}
