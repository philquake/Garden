import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/analytics/analytics.dart';
import 'package:garden/export/backup.dart';
import 'package:garden/export/file_transfer.dart';
import 'package:garden/state/garden_controller.dart';
import 'package:garden/ui/home_screen.dart';
import 'package:garden/ui/settings_screen.dart';

import '../support.dart';

final garden2 = [
  tracked(habit('a', name: 'Read'), [testToday - 1, testToday]),
  tracked(habit('b', name: 'Run'), [testToday]),
];

Future<FakeFileTransfer> open(
  WidgetTester tester, {
  bool unlocked = true,
  FakePurchases? purchases,
  FakeFileTransfer? transfer,
  Analytics? analytics,
}) async {
  final t = transfer ?? FakeFileTransfer();
  await pumpScreen(
    tester,
    const SettingsScreen(),
    habits: garden2,
    unlocked: unlocked,
    purchases: purchases,
    extra: [
      fileTransferProvider.overrideWithValue(t),
      if (analytics != null) analyticsProvider.overrideWithValue(analytics),
    ],
  );
  return t;
}

Future<void> tapTile(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await settle(tester);
}

void main() {
  group('export as CSV', () {
    testWidgets('shares the completions and habits files', (tester) async {
      final t = await open(tester);
      await tapTile(tester, 'export-csv');
      expect(t.shared.length, 1);
      expect(t.shared.single.map((f) => f.name), [
        'garden-completions-2024-10-04.csv',
        'garden-habits-2024-10-04.csv',
      ]);
      expect(t.shared.single.first.contents, contains('Read,2024-10-04,1'));
    });

    testWidgets('a locked garden offers the unlock first, then shares', (
      tester,
    ) async {
      final t = await open(tester, unlocked: false, purchases: FakePurchases());
      await tapTile(tester, 'export-csv');
      expect(t.shared, isEmpty);
      expect(find.byKey(const Key('unlock-buy')), findsOneWidget);
      await tester.tap(find.byKey(const Key('unlock-buy')));
      await settle(tester);
      expect(t.shared.length, 1);
    });

    testWidgets('declining the unlock shares nothing', (tester) async {
      final t = await open(tester, unlocked: false, purchases: FakePurchases());
      await tapTile(tester, 'export-csv');
      await tester.tap(find.byKey(const Key('unlock-later')));
      await settle(tester);
      expect(t.shared, isEmpty);
    });

    testWidgets('a share that fails says so gently', (tester) async {
      final t = FakeFileTransfer()..shareError = StateError('no share sheet');
      await open(tester, transfer: t);
      await tapTile(tester, 'export-csv');
      expect(find.textContaining("didn't go through"), findsOneWidget);
    });
  });

  group('back up and restore', () {
    testWidgets('backs up the whole garden to one file', (tester) async {
      final t = await open(tester);
      await tapTile(tester, 'backup');
      final file = t.shared.single.single;
      expect(file.name, 'garden-backup-2024-10-04.json');
      final back = decodeBackup(file.contents);
      expect(back.map((h) => h.config.name), ['Read', 'Run']);
      expect(back.first.log.keys, {testToday - 1, testToday});
    });

    testWidgets('restoring replaces the garden after a warning', (
      tester,
    ) async {
      final t = FakeFileTransfer()
        ..pick = encodeBackup([
          tracked(habit('z', name: 'From old phone'), [testToday - 5]),
        ], testToday);
      await open(tester, transfer: t);
      await tapTile(tester, 'restore-backup');
      expect(find.textContaining('replaces everything'), findsOneWidget);
      expect(t.picks, 0);
      await tester.tap(find.byKey(const Key('confirm-restore')));
      await settle(tester);
      final now = containerOf(tester).read(gardenProvider);
      expect(now.map((h) => h.config.name), ['From old phone']);
      expect(now.single.log, {testToday - 5: 1});
      expect(find.text('Restored 1 habit.'), findsOneWidget);
    });

    testWidgets('Cancel on the warning touches nothing', (tester) async {
      final t = FakeFileTransfer();
      await open(tester, transfer: t);
      await tapTile(tester, 'restore-backup');
      await tester.tap(find.byKey(const Key('cancel-restore')));
      await settle(tester);
      expect(t.picks, 0);
      expect(containerOf(tester).read(gardenProvider).length, 2);
    });

    testWidgets('cancelling the file picker touches nothing', (tester) async {
      final t = FakeFileTransfer(); // pick == null
      await open(tester, transfer: t);
      await tapTile(tester, 'restore-backup');
      await tester.tap(find.byKey(const Key('confirm-restore')));
      await settle(tester);
      expect(t.picks, 1);
      expect(containerOf(tester).read(gardenProvider).length, 2);
      expect(find.textContaining('Restored'), findsNothing);
    });

    testWidgets('a file that is not a backup is refused with a reason', (
      tester,
    ) async {
      final t = FakeFileTransfer()..pick = 'just some text';
      await open(tester, transfer: t);
      await tapTile(tester, 'restore-backup');
      await tester.tap(find.byKey(const Key('confirm-restore')));
      await settle(tester);
      expect(find.text('That file is not a Garden backup.'), findsOneWidget);
      expect(containerOf(tester).read(gardenProvider).length, 2);
    });

    testWidgets('a damaged backup changes nothing', (tester) async {
      final good = encodeBackup(garden2, testToday);
      final t = FakeFileTransfer()..pick = good.replaceFirst('Run', 'Rum');
      await open(tester, transfer: t);
      await tapTile(tester, 'restore-backup');
      await tester.tap(find.byKey(const Key('confirm-restore')));
      await settle(tester);
      expect(find.textContaining('damaged'), findsOneWidget);
      expect(
        containerOf(tester).read(gardenProvider).map((h) => h.config.name),
        ['Read', 'Run'],
      );
    });

    testWidgets('a picker error (too big) is shown as its message', (
      tester,
    ) async {
      final t = FakeFileTransfer()
        ..pickError = const BackupException('That file is too big.');
      await open(tester, transfer: t);
      await tapTile(tester, 'restore-backup');
      await tester.tap(find.byKey(const Key('confirm-restore')));
      await settle(tester);
      expect(find.text('That file is too big.'), findsOneWidget);
    });

    testWidgets('a locked garden cannot restore a backup either', (
      tester,
    ) async {
      final t = await open(tester, unlocked: false);
      await tapTile(tester, 'restore-backup');
      expect(find.byKey(const Key('unlock-buy')), findsOneWidget);
      expect(find.byKey(const Key('confirm-restore')), findsNothing);
      expect(t.picks, 0);
    });
  });

  testWidgets('locked data tools show a lock', (tester) async {
    await open(tester, unlocked: false);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(3));
  });

  testWidgets('unlocked data tools show no lock', (tester) async {
    await open(tester);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets('the screen explains phone backup and moving phones', (
    tester,
  ) async {
    await open(tester);
    expect(find.textContaining('Google or iCloud'), findsOneWidget);
  });

  group('anonymous usage', () {
    testWidgets('the switch is off until asked, and saying yes sticks', (
      tester,
    ) async {
      final sink = RecordingSink();
      final a = (await tester.runAsync(() => makeAnalytics(sink)))!;
      await open(tester, analytics: a);
      Switch sw() => tester.widget<Switch>(find.byType(Switch));
      expect(sw().value, isFalse);
      await tapTile(tester, 'analytics-switch');
      expect(sw().value, isTrue);
      expect(a.optedIn, isTrue);
      await tapTile(tester, 'analytics-switch');
      expect(sw().value, isFalse);
      expect(a.optedIn, isFalse);
    });

    testWidgets('exports are counted only when opted in', (tester) async {
      final sink = RecordingSink();
      final a = (await tester.runAsync(
        () => makeAnalytics(sink, answer: true),
      ))!;
      await open(tester, analytics: a);
      await tapTile(tester, 'export-csv');
      await tapTile(tester, 'backup');
      expect(sink.names, ['export_used', 'backup_used']);
    });

    testWidgets('and never when not', (tester) async {
      final sink = RecordingSink();
      final a = (await tester.runAsync(
        () => makeAnalytics(sink, answer: false),
      ))!;
      await open(tester, analytics: a);
      await tapTile(tester, 'export-csv');
      expect(sink.events, isEmpty);
    });
  });

  group('the one-time ask on the home screen', () {
    Future<Analytics> home(WidgetTester tester, {bool? answer}) async {
      final a = (await tester.runAsync(
        () => makeAnalytics(RecordingSink(), answer: answer),
      ))!;
      await pumpScreen(
        tester,
        HomeScreen(onAdd: () {}, onOpen: (_) {}),
        habits: garden2,
        extra: [analyticsProvider.overrideWithValue(a)],
      );
      return a;
    }

    testWidgets('appears until answered, then never again', (tester) async {
      final a = await home(tester);
      expect(find.byKey(const Key('analytics-ask')), findsOneWidget);
      await tester.tap(find.byKey(const Key('analytics-yes')));
      await settle(tester);
      expect(find.byKey(const Key('analytics-ask')), findsNothing);
      expect(a.optedIn, isTrue);
    });

    testWidgets('No thanks is respected', (tester) async {
      final a = await home(tester);
      await tester.tap(find.byKey(const Key('analytics-no')));
      await settle(tester);
      expect(find.byKey(const Key('analytics-ask')), findsNothing);
      expect(a.asked, isTrue);
      expect(a.optedIn, isFalse);
    });

    testWidgets('is not shown to someone who already answered', (tester) async {
      await home(tester, answer: false);
      expect(find.byKey(const Key('analytics-ask')), findsNothing);
    });

    testWidgets('says what is and is not collected', (tester) async {
      await home(tester);
      expect(
        find.textContaining('Never your habits, names or notes'),
        findsOneWidget,
      );
    });
  });
}
