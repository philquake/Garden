import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/notification_plan.dart';
import '../state/garden_controller.dart';
import 'schedule_math.dart';
import 'scheduler.dart';

/// iOS keeps only 64 pending notifications.
const maxScheduled = 60;

final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => const NoopScheduler(),
);

final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Future items only, deduped by id, soonest first, capped at [maxScheduled].
List<ScheduledItem> selectItems(
  List<PlannedNotification> planned,
  DateTime now,
) {
  final seen = <int>{};
  final items =
      <ScheduledItem>[
        for (final n in planned)
          if (localWhen(n).isAfter(now) && seen.add(n.id))
            ScheduledItem(n, localWhen(n)),
      ]..sort((a, b) {
        return a.when.compareTo(b.when);
      });
  return items.take(maxScheduled).toList();
}

class NotificationSync {
  NotificationSync(this._ref);
  final Ref _ref;
  bool _running = false;
  bool _again = false;

  /// Replans now, or once more after the running replan finishes.
  Future<void> replan() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _once();
      } while (_again);
    } finally {
      _running = false;
    }
  }

  Future<void> _once() async {
    try {
      final now = _ref.read(nowProvider)();
      // nowMinutes is wall-clock but `today` is the 3am-shifted day index (at
      // 01:30 on calendar day D, today = D-1); selectItems' isAfter(now)
      // filter drops anything already past, so the combination is correct.
      final planned = planNotifications(
        _ref.read(gardenProvider),
        _ref.read(todayProvider),
        nowMinutes: now.hour * 60 + now.minute,
      );
      final scheduler = _ref.read(notificationSchedulerProvider);
      final items = selectItems(planned, now);
      // Schedule first, then drop what is no longer planned: a crash between
      // the two never leaves the garden without reminders.
      await scheduler.scheduleAll(items);
      await scheduler.cancelExcept({for (final i in items) i.n.id});
    } catch (e) {
      debugPrint('Notification replan failed: $e');
    }
  }
}

/// Read once at app start; replans now and after every garden change.
final notificationSyncProvider = Provider<NotificationSync>((ref) {
  final sync = NotificationSync(ref);
  ref.listen(gardenProvider, (_, _) => sync.replan());
  sync.replan();
  return sync;
});
