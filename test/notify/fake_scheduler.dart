import 'dart:async';

import 'package:garden/notify/scheduler.dart';

class FakeScheduler implements NotificationScheduler {
  FakeScheduler({this.permission = true});
  bool permission;
  final calls = <String>[];
  final scheduled = <List<ScheduledItem>>[];
  int permissionRequests = 0;
  bool throwing = false;

  /// When set, the next cancelAll waits for it (to hold a replan open).
  Completer<void>? hold;
  int running = 0;
  int maxRunning = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<void> cancelAll() async {
    running++;
    if (running > maxRunning) maxRunning = running;
    calls.add('cancel');
    try {
      if (throwing) throw StateError('boom');
      final h = hold;
      hold = null;
      if (h != null) await h.future;
    } finally {
      running--;
    }
  }

  @override
  Future<void> scheduleAll(List<ScheduledItem> items) async {
    calls.add('schedule');
    scheduled.add(items);
  }
}
