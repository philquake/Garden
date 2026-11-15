import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The only things ever counted. No habit names, notes or values, ever.
enum AnalyticsEvent {
  firstOpen('first_open'),
  dailyActive('daily_active'),
  habitCreated('habit_created'),
  firstCompletion('first_completion'),
  paywallViewed('paywall_viewed'),
  purchase('purchase'),
  exportUsed('export_used'),
  backupUsed('backup_used'),
  day1Return('day_1_return'),
  day7Return('day_7_return'),
  day30Return('day_30_return');

  const AnalyticsEvent(this.wire);
  final String wire;
}

/// Where counted events go. The backend is not chosen yet, so the app ships
/// with [NoopSink]; swap it in main() when it is.
abstract class AnalyticsSink {
  void send(String event, String installId);
}

class NoopSink implements AnalyticsSink {
  const NoopSink();

  @override
  void send(String event, String installId) {}
}

const _optIn = 'analytics_opt_in';
const _id = 'analytics_install_id';
const _firstDay = 'analytics_first_day';
const _lastDay = 'analytics_last_day';
const _sent = 'analytics_sent_once';

/// Anonymous usage counts, off until the person says yes. A random install id
/// is made on opt-in and deleted on opt-out, along with everything below.
class Analytics {
  Analytics(this._prefs, this._sink);

  /// Always off: nothing is asked, stored or sent.
  const Analytics.off() : _prefs = null, _sink = const NoopSink();

  final SharedPreferences? _prefs;
  final AnalyticsSink _sink;

  /// Whether the person has answered, either way.
  bool get asked => _prefs == null || _prefs.containsKey(_optIn);

  bool get optedIn => _prefs?.getBool(_optIn) ?? false;

  Future<void> setOptIn(bool value) async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_optIn, value);
    if (value) {
      if (p.getString(_id) == null) await p.setString(_id, _newId());
    } else {
      for (final k in [_id, _firstDay, _lastDay, _sent]) {
        await p.remove(k);
      }
    }
  }

  void track(AnalyticsEvent e) {
    final id = _prefs?.getString(_id);
    if (!optedIn || id == null) return;
    try {
      _sink.send(e.wire, id);
    } catch (_) {
      // Counting must never get in the way of the app.
    }
  }

  /// Counts [e] the first time only.
  void trackOnce(AnalyticsEvent e) {
    final p = _prefs;
    if (p == null || !optedIn) return;
    final sent = p.getStringList(_sent) ?? const [];
    if (sent.contains(e.wire)) return;
    p.setStringList(_sent, [...sent, e.wire]);
    track(e);
  }

  /// Call when the app opens or returns to the foreground.
  void appOpened(int today) {
    final p = _prefs;
    if (p == null || !optedIn) return;
    final first = p.getInt(_firstDay);
    if (first == null) {
      p.setInt(_firstDay, today);
      trackOnce(AnalyticsEvent.firstOpen);
    }
    if (p.getInt(_lastDay) == today) return;
    p.setInt(_lastDay, today);
    track(AnalyticsEvent.dailyActive);
    switch (today - (first ?? today)) {
      case 1:
        trackOnce(AnalyticsEvent.day1Return);
      case 7:
        trackOnce(AnalyticsEvent.day7Return);
      case 30:
        trackOnce(AnalyticsEvent.day30Return);
    }
  }

  static String _newId() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }
}

final analyticsProvider = Provider<Analytics>((ref) => const Analytics.off());

/// Whether the person has opted in: null until they have been asked.
final analyticsConsentProvider = NotifierProvider<Consent, bool?>(Consent.new);

class Consent extends Notifier<bool?> {
  Analytics get _a => ref.read(analyticsProvider);

  @override
  bool? build() => _a.asked ? _a.optedIn : null;

  Future<void> set(bool value) async {
    await _a.setOptIn(value);
    if (ref.mounted) state = value;
  }
}
