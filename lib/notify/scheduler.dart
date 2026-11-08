import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../domain/notification_plan.dart';

class ScheduledItem {
  const ScheduledItem(this.n, this.when);
  final PlannedNotification n;

  /// Local wall-clock instant.
  final DateTime when;
}

abstract class NotificationScheduler {
  Future<bool> requestPermission();

  /// Schedules [items]; an item with an id already pending replaces it.
  Future<void> scheduleAll(List<ScheduledItem> items);

  /// Cancels every pending notification whose id is not in [keep]. Called
  /// after [scheduleAll], so a crash in between leaves old reminders, never none.
  Future<void> cancelExcept(Set<int> keep);
}

class NoopScheduler implements NotificationScheduler {
  const NoopScheduler();
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> scheduleAll(List<ScheduledItem> items) async {}
  @override
  Future<void> cancelExcept(Set<int> keep) async {}
}

/// Tapping a notification just opens the app; deep-linking is out of scope.
class LocalNotificationScheduler implements NotificationScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Nothing may prompt at launch; permission is asked when a reminder
        // is first switched on.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  @override
  Future<void> cancelExcept(Set<int> keep) async {
    for (final r in await _plugin.pendingNotificationRequests()) {
      if (!keep.contains(r.id)) await _plugin.cancel(id: r.id);
    }
  }

  @override
  Future<void> scheduleAll(List<ScheduledItem> items) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'garden_reminders',
        'Garden reminders',
      ),
      iOS: DarwinNotificationDetails(),
    );
    for (final i in items) {
      await _plugin.zonedSchedule(
        id: i.n.id,
        title: i.n.title,
        body: i.n.body,
        // An absolute instant, so it does not depend on tz.local being set.
        scheduledDate: tz.TZDateTime.from(i.when, tz.UTC),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
