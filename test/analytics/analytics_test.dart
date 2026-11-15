import 'package:flutter_test/flutter_test.dart';
import 'package:garden/analytics/analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support.dart';

class ThrowingSink extends RecordingSink {
  bool throwing = false;

  @override
  void send(String event, String installId) {
    if (throwing) throw StateError('network down');
    super.send(event, installId);
  }
}

Future<(Analytics, ThrowingSink, SharedPreferences)> make([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final sink = ThrowingSink();
  return (Analytics(prefs, sink), sink, prefs);
}

void main() {
  test('nothing is asked or sent until the person says yes', () async {
    final (a, sink, prefs) = await make();
    expect(a.asked, isFalse);
    expect(a.optedIn, isFalse);
    a.track(AnalyticsEvent.purchase);
    a.trackOnce(AnalyticsEvent.firstCompletion);
    a.appOpened(100);
    expect(sink.events, isEmpty);
    expect(prefs.getKeys(), isEmpty);
  });

  test('saying no is remembered and still sends nothing', () async {
    final (a, sink, _) = await make();
    await a.setOptIn(false);
    expect(a.asked, isTrue);
    expect(a.optedIn, isFalse);
    a.track(AnalyticsEvent.purchase);
    a.appOpened(100);
    expect(sink.events, isEmpty);
  });

  test(
    'opting in makes a random install id and events carry only it',
    () async {
      final (a, sink, prefs) = await make();
      await a.setOptIn(true);
      final id = prefs.getString('analytics_install_id')!;
      expect(id, matches(RegExp(r'^[0-9a-f]{16}$')));
      a.track(AnalyticsEvent.habitCreated);
      expect(sink.events, [('habit_created', id)]);
      await a.setOptIn(true);
      expect(prefs.getString('analytics_install_id'), id); // not regenerated
    },
  );

  test('two installs get different ids', () async {
    final (a, _, p1) = await make();
    await a.setOptIn(true);
    final (b, _, p2) = await make();
    await b.setOptIn(true);
    expect(
      p1.getString('analytics_install_id'),
      isNot(p2.getString('analytics_install_id')),
    );
  });

  test('opting out deletes the id and everything remembered', () async {
    final (a, sink, prefs) = await make();
    await a.setOptIn(true);
    a.appOpened(100);
    await a.setOptIn(false);
    expect(prefs.getKeys(), {'analytics_opt_in'});
    sink.events.clear();
    a.track(AnalyticsEvent.purchase);
    expect(sink.events, isEmpty);
  });

  test('trackOnce sends a milestone once, even across restarts', () async {
    final (a, sink, prefs) = await make();
    await a.setOptIn(true);
    a.trackOnce(AnalyticsEvent.firstCompletion);
    a.trackOnce(AnalyticsEvent.firstCompletion);
    expect(sink.names, ['first_completion']);
    final again = Analytics(prefs, sink);
    again.trackOnce(AnalyticsEvent.firstCompletion);
    expect(sink.names, ['first_completion']);
  });

  group('opening the app', () {
    test('the first open, then one daily-active per day', () async {
      final (a, sink, _) = await make();
      await a.setOptIn(true);
      a.appOpened(100);
      a.appOpened(100);
      expect(sink.names, ['first_open', 'daily_active']);
      a.appOpened(100);
      a.appOpened(103);
      expect(sink.names, ['first_open', 'daily_active', 'daily_active']);
    });

    test(
      'day 1, 7 and 30 returns are counted once each, on those days',
      () async {
        final (a, sink, _) = await make();
        await a.setOptIn(true);
        for (final d in [100, 101, 101, 105, 107, 107, 130, 137, 137]) {
          a.appOpened(d);
        }
        expect(sink.names.where((n) => n.endsWith('_return')), [
          'day_1_return',
          'day_7_return',
          'day_30_return',
        ]);
      },
    );

    test(
      'a person who skips day 1 does not get a day-1 return later',
      () async {
        final (a, sink, _) = await make();
        await a.setOptIn(true);
        a.appOpened(100);
        a.appOpened(102);
        expect(sink.names.where((n) => n.endsWith('_return')), isEmpty);
      },
    );
  });

  test('a failing backend never throws into the app', () async {
    final (a, sink, _) = await make();
    await a.setOptIn(true);
    sink.throwing = true;
    expect(() => a.track(AnalyticsEvent.purchase), returnsNormally);
    expect(() => a.appOpened(100), returnsNormally);
  });

  test('the off switch ignores everything', () async {
    const a = Analytics.off();
    expect(a.asked, isTrue);
    expect(a.optedIn, isFalse);
    await a.setOptIn(true);
    expect(a.optedIn, isFalse);
    a.track(AnalyticsEvent.purchase);
  });

  test('event names are fixed snake_case words with nothing personal', () {
    for (final e in AnalyticsEvent.values) {
      expect(e.wire, matches(RegExp(r'^[a-z0-9_]+$')));
    }
    expect(AnalyticsEvent.values.length, 11);
  });
}
