import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/analytics/analytics.dart';
import 'package:garden/app.dart';
import 'package:garden/purchases/purchases.dart';
import 'package:garden/state/garden_controller.dart';
import 'package:garden/ui/home_screen.dart';

import '../support.dart';

void main() {
  group('events from the controller', () {
    test('adding a habit is counted, with nothing about the habit', () async {
      final sink = RecordingSink();
      final a = await makeAnalytics(sink, answer: true);
      final c = makeContainer(
        overrides: [analyticsProvider.overrideWithValue(a)],
      );
      await c.read(gardenProvider.notifier).add(habit('a', name: 'Secret'));
      expect(sink.names, ['habit_created']);
      expect(sink.events.single.toString(), isNot(contains('Secret')));
    });

    test(
      'the first logged day is counted once, however often you log',
      () async {
        final sink = RecordingSink();
        final a = await makeAnalytics(sink, answer: true);
        final c = makeContainer(
          habits: [tracked(habit('a'))],
          overrides: [analyticsProvider.overrideWithValue(a)],
        );
        final g = c.read(gardenProvider.notifier);
        await g.setValue('a', testToday, 1);
        await g.setValue('a', testToday, null);
        await g.setValue('a', testToday - 1, 1);
        expect(sink.names, ['first_completion']);
      },
    );

    test('clearing a day is not a completion', () async {
      final sink = RecordingSink();
      final a = await makeAnalytics(sink, answer: true);
      final c = makeContainer(
        habits: [
          tracked(habit('a'), [testToday]),
        ],
        overrides: [analyticsProvider.overrideWithValue(a)],
      );
      await c.read(gardenProvider.notifier).setValue('a', testToday, null);
      expect(sink.events, isEmpty);
    });

    test('nothing at all is sent when the person has not opted in', () async {
      final sink = RecordingSink();
      final a = await makeAnalytics(sink);
      final c = makeContainer(
        overrides: [analyticsProvider.overrideWithValue(a)],
      );
      await c.read(gardenProvider.notifier).add(habit('a'));
      await c.read(gardenProvider.notifier).setValue('a', testToday, 1);
      expect(sink.events, isEmpty);
    });

    test('a purchase is counted, a cancelled one is not', () async {
      final sink = RecordingSink();
      final a = await makeAnalytics(sink, answer: true);
      final cancelled = ProviderContainer(
        overrides: [
          analyticsProvider.overrideWithValue(a),
          purchasesProvider.overrideWithValue(
            FakePurchases(buyResult: PurchaseResult.cancelled),
          ),
        ],
      );
      addTearDown(cancelled.dispose);
      await cancelled.read(unlockedProvider.notifier).buy();
      expect(sink.events, isEmpty);
      final ok = ProviderContainer(
        overrides: [
          analyticsProvider.overrideWithValue(a),
          purchasesProvider.overrideWithValue(FakePurchases()),
        ],
      );
      addTearDown(ok.dispose);
      await ok.read(unlockedProvider.notifier).buy();
      expect(sink.names, ['purchase']);
    });
  });

  testWidgets('opening the paywall is counted', (tester) async {
    final sink = RecordingSink();
    final a = (await tester.runAsync(() => makeAnalytics(sink, answer: true)))!;
    await pumpScreen(
      tester,
      HomeScreen(onAdd: () {}, onOpen: (_) {}),
      unlocked: false,
      habits: [
        for (final id in ['a', 'b', 'c']) tracked(habit(id)),
      ],
      extra: [analyticsProvider.overrideWithValue(a)],
    );
    expect(sink.events, isEmpty); // not at launch
    await tester.tap(find.byKey(const Key('add-habit')));
    await settle(tester);
    expect(sink.names, ['paywall_viewed']);
  });

  testWidgets('starting the app counts the first open and the day', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sink = RecordingSink();
    final a = (await tester.runAsync(() => makeAnalytics(sink, answer: true)))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: gardenOverrides(
          extra: [analyticsProvider.overrideWithValue(a)],
        ),
        child: const GardenApp(),
      ),
    );
    await settle(tester);
    expect(sink.names, ['first_open', 'daily_active']);
  });
}
