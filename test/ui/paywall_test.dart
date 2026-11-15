import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/purchases/purchases.dart';
import 'package:garden/state/garden_controller.dart';
import 'package:garden/ui/habit_form.dart';
import 'package:garden/ui/habit_screen.dart';
import 'package:garden/ui/home_screen.dart';
import 'package:garden/ui/settings_screen.dart';

import '../support.dart';

final three = [
  for (final id in ['a', 'b', 'c']) tracked(habit(id)),
];

Widget home({VoidCallback? onAdd}) =>
    HomeScreen(onAdd: onAdd ?? () {}, onOpen: (_) {});

void main() {
  group('adding the fourth habit', () {
    testWidgets('a free garden with room just opens the form', (tester) async {
      var added = 0;
      await pumpScreen(
        tester,
        home(onAdd: () => added++),
        unlocked: false,
        habits: three.take(2).toList(),
      );
      await tester.tap(find.byKey(const Key('add-habit')));
      await settle(tester);
      expect(added, 1);
      expect(find.text('Unlock Garden'), findsNothing);
    });

    testWidgets('a full free garden offers the unlock instead', (tester) async {
      var added = 0;
      await pumpScreen(
        tester,
        home(onAdd: () => added++),
        unlocked: false,
        habits: three,
      );
      await tester.tap(find.byKey(const Key('add-habit')));
      await settle(tester);
      expect(added, 0);
      expect(find.text('Unlock Garden'), findsOneWidget);
      expect(find.text('Unlock for \$9.99'), findsOneWidget);
      expect(
        find.textContaining('No subscription, no account'),
        findsOneWidget,
      );
    });

    testWidgets('an unlocked garden never sees it', (tester) async {
      var added = 0;
      await pumpScreen(tester, home(onAdd: () => added++), habits: three);
      await tester.tap(find.byKey(const Key('add-habit')));
      await settle(tester);
      expect(added, 1);
    });

    testWidgets('nothing is offered until something locked is tapped', (
      tester,
    ) async {
      await pumpScreen(tester, home(), unlocked: false, habits: three);
      expect(find.text('Unlock Garden'), findsNothing);
      expect(find.byKey(const Key('unlock-buy')), findsNothing);
    });
  });

  group('the paywall', () {
    Future<void> openPaywall(
      WidgetTester tester,
      FakePurchases purchases,
    ) async {
      await pumpScreen(tester, home(), purchases: purchases, habits: three);
      await tester.tap(find.byKey(const Key('add-habit')));
      await settle(tester);
    }

    testWidgets(
      'buying unlocks and closes, and the price comes from the store',
      (tester) async {
        final p = FakePurchases(price: '£7.99');
        await openPaywall(tester, p);
        expect(find.text('Unlock for £7.99'), findsOneWidget);
        await tester.tap(find.byKey(const Key('unlock-buy')));
        await settle(tester);
        expect(p.buys, 1);
        expect(find.byKey(const Key('unlock-buy')), findsNothing);
        expect(containerOf(tester).read(unlockedProvider), isTrue);
      },
    );

    testWidgets('cancelling the store sheet keeps the offer open', (
      tester,
    ) async {
      final p = FakePurchases(buyResult: PurchaseResult.cancelled);
      await openPaywall(tester, p);
      await tester.tap(find.byKey(const Key('unlock-buy')));
      await settle(tester);
      expect(find.byKey(const Key('unlock-buy')), findsOneWidget);
      expect(containerOf(tester).read(unlockedProvider), isFalse);
    });

    testWidgets('a failed purchase says so gently', (tester) async {
      await openPaywall(
        tester,
        FakePurchases(buyResult: PurchaseResult.failed),
      );
      await tester.tap(find.byKey(const Key('unlock-buy')));
      await settle(tester);
      expect(find.textContaining("didn't go through"), findsOneWidget);
      expect(containerOf(tester).read(unlockedProvider), isFalse);
    });

    testWidgets('with no store connected it says the store is unavailable', (
      tester,
    ) async {
      await openPaywall(
        tester,
        FakePurchases(buyResult: PurchaseResult.unavailable),
      );
      await tester.tap(find.byKey(const Key('unlock-buy')));
      await settle(tester);
      expect(find.textContaining("store isn't available"), findsOneWidget);
    });

    testWidgets('restore finds an earlier purchase', (tester) async {
      final p = FakePurchases(restorable: true);
      await openPaywall(tester, p);
      await tester.tap(find.byKey(const Key('unlock-restore')));
      await settle(tester);
      expect(p.restores, 1);
      expect(containerOf(tester).read(unlockedProvider), isTrue);
      expect(find.byKey(const Key('unlock-buy')), findsNothing);
    });

    testWidgets('restore with nothing to restore says so', (tester) async {
      await openPaywall(tester, FakePurchases());
      await tester.tap(find.byKey(const Key('unlock-restore')));
      await settle(tester);
      expect(find.textContaining('No earlier purchase'), findsOneWidget);
      expect(find.byKey(const Key('unlock-buy')), findsOneWidget);
    });

    testWidgets('Not now closes it and changes nothing', (tester) async {
      final p = FakePurchases();
      await openPaywall(tester, p);
      await tester.tap(find.byKey(const Key('unlock-later')));
      await settle(tester);
      expect(find.byKey(const Key('unlock-buy')), findsNothing);
      expect(p.buys, 0);
      expect(containerOf(tester).read(gardenProvider).length, 3);
    });

    testWidgets('the buttons are at least 44 high', (tester) async {
      await openPaywall(tester, FakePurchases());
      for (final k in ['unlock-buy', 'unlock-restore', 'unlock-later']) {
        final size = tester.getSize(find.byKey(Key(k)));
        expect(size.height, greaterThanOrEqualTo(44), reason: k);
        expect(size.width, greaterThanOrEqualTo(44), reason: k);
      }
    });
  });

  testWidgets('a save past the limit from the form offers the unlock', (
    tester,
  ) async {
    await pumpScreen(tester, const HabitForm(), unlocked: false, habits: three);
    await tester.enterText(find.byKey(const Key('name-field')), 'Fourth');
    await tester.tap(find.byKey(const Key('save-button')));
    await settle(tester);
    expect(find.text('Unlock Garden'), findsOneWidget);
    expect(containerOf(tester).read(gardenProvider).length, 3);
  });

  group('settings', () {
    testWidgets('a locked garden offers the unlock and restore', (
      tester,
    ) async {
      await pumpScreen(tester, const SettingsScreen(), unlocked: false);
      expect(find.byKey(const Key('unlock-tile')), findsOneWidget);
      expect(find.byKey(const Key('restore-tile')), findsOneWidget);
      expect(find.text('One payment, \$9.99'), findsOneWidget);
    });

    testWidgets('restore is always there, and reports what it found', (
      tester,
    ) async {
      final p = FakePurchases(restorable: true);
      await pumpScreen(tester, const SettingsScreen(), purchases: p);
      await tester.tap(find.byKey(const Key('restore-tile')));
      await settle(tester);
      expect(find.text('Your purchase is restored.'), findsOneWidget);
      expect(find.byKey(const Key('unlock-status')), findsOneWidget);
      expect(find.byKey(const Key('restore-tile')), findsOneWidget);
    });

    testWidgets('restore with nothing found says so', (tester) async {
      await pumpScreen(
        tester,
        const SettingsScreen(),
        purchases: FakePurchases(),
      );
      await tester.tap(find.byKey(const Key('restore-tile')));
      await settle(tester);
      expect(find.textContaining('No earlier purchase'), findsOneWidget);
    });

    testWidgets('an unlocked garden says thank you', (tester) async {
      await pumpScreen(tester, const SettingsScreen());
      expect(find.byKey(const Key('unlock-status')), findsOneWidget);
      expect(find.byKey(const Key('unlock-tile')), findsNothing);
    });

    testWidgets('the home screen opens settings', (tester) async {
      await pumpScreen(tester, home());
      await tester.tap(find.byKey(const Key('open-settings')));
      await settle(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  group('locked detail screen', () {
    final h = tracked(habit('a', name: 'Read', createdDay: testToday - 40), [
      for (var i = 0; i < 5; i++) testToday - i,
    ]);

    testWidgets('keeps the basics, locks the charts and best streaks', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const HabitScreen(habitId: 'a'),
        unlocked: false,
        habits: [h],
      );
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.byKey(const Key('status-line')), findsOneWidget);
      expect(find.byKey(const Key('range')), findsNothing);
      expect(find.text('Score'), findsNothing);
      expect(find.text('History'), findsNothing);
      expect(find.text('Score and history'), findsOneWidget);
      expect(find.text('Best streaks'), findsOneWidget);
      expect(find.byKey(const Key('locked-best-streaks')), findsOneWidget);
    });

    testWidgets('this month stays editable', (tester) async {
      final db = FakeGardenDb([h]);
      await pumpScreen(
        tester,
        const HabitScreen(habitId: 'a'),
        unlocked: false,
        habits: [h],
        db: db,
      );
      final day = testToday - 3; // 1 Oct, still this month
      await tester.ensureVisible(find.byKey(Key('day-$day')));
      await tester.tap(find.byKey(Key('day-$day')));
      await settle(tester);
      expect(db.logs['a']!.containsKey(day), isFalse); // it was logged: cleared
    });

    testWidgets('earlier months offer the unlock', (tester) async {
      await pumpScreen(
        tester,
        const HabitScreen(habitId: 'a'),
        unlocked: false,
        habits: [h],
      );
      await tester.ensureVisible(find.byKey(const Key('month-prev')));
      await tester.tap(find.byKey(const Key('month-prev')));
      await settle(tester);
      expect(find.text('Unlock Garden'), findsWidgets);
      expect(find.byKey(const Key('unlock-buy')), findsOneWidget);
      expect(find.text('Oct 2024'), findsOneWidget); // did not move
    });

    testWidgets('unlocking from a locked card reveals the charts', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const HabitScreen(habitId: 'a'),
        purchases: FakePurchases(),
        habits: [h],
      );
      await tester.ensureVisible(
        find.byKey(const Key('locked-score-and-history')),
      );
      await tester.tap(find.byKey(const Key('locked-score-and-history')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('unlock-buy')));
      await settle(tester);
      expect(find.byKey(const Key('range')), findsOneWidget);
      expect(find.text('Score'), findsOneWidget);
    });
  });
}
