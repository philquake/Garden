import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/analytics/analytics.dart';
import 'package:garden/data/garden_db.dart';
import 'package:garden/domain/habit_config.dart';
import 'package:garden/domain/schedule.dart';
import 'package:garden/domain/stats.dart';
import 'package:garden/export/csv.dart';
import 'package:garden/export/file_transfer.dart';
import 'package:garden/purchases/purchases.dart';
import 'package:garden/state/garden_controller.dart';
import 'package:garden/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2024-10-04, a Friday.
const testToday = 20000;

class FixedToday extends Today {
  FixedToday(this.day);
  final int day;

  @override
  int build() => day;
}

class RecordingSink implements AnalyticsSink {
  final events = <(String, String)>[];

  @override
  void send(String event, String installId) => events.add((event, installId));

  List<String> get names => [for (final e in events) e.$1];
}

/// Analytics over in-memory preferences. [answer] null means "not asked yet".
Future<Analytics> makeAnalytics(RecordingSink sink, {bool? answer}) async {
  SharedPreferences.setMockInitialValues({});
  final a = Analytics(await SharedPreferences.getInstance(), sink);
  if (answer != null) await a.setOptIn(answer);
  return a;
}

class FakeFileTransfer implements FileTransfer {
  final shared = <List<ExportFile>>[];

  /// What the next pickBackup returns (null = the person cancelled).
  String? pick;
  Object? pickError;
  Object? shareError;
  int picks = 0;

  @override
  Future<void> share(List<ExportFile> files) async {
    if (shareError != null) throw shareError!;
    shared.add(files);
  }

  @override
  Future<String?> pickBackup() async {
    picks++;
    if (pickError != null) throw pickError!;
    return pick;
  }
}

/// Starts as given and never talks to a store.
class FixedUnlocked extends Unlocked {
  FixedUnlocked(this.value);
  final bool value;

  @override
  bool build() => value;
}

class FakePurchases implements Purchases {
  FakePurchases({
    this.owned = false,
    this.buyResult = PurchaseResult.unlocked,
    this.restorable = false,
    this.price = r'$9.99',
  });

  bool owned;
  PurchaseResult buyResult;
  bool restorable;
  final String price;
  int buys = 0;
  int restores = 0;

  @override
  Future<bool> isUnlocked() async => owned;

  @override
  String get priceLabel => price;

  @override
  Future<PurchaseResult> buy() async {
    buys++;
    if (buyResult == PurchaseResult.unlocked) owned = true;
    return buyResult;
  }

  @override
  Future<bool> restore() async {
    restores++;
    if (restorable) owned = true;
    return restorable;
  }
}

/// In-memory stand-in for [GardenDb], so widget tests need no real database.
class FakeGardenDb implements GardenDb {
  FakeGardenDb([List<Tracked> habits = const []]) {
    for (final t in habits) {
      configs[t.config.id] = t.config;
      logs[t.config.id] = {...t.log};
    }
  }

  final configs = <String, HabitConfig>{};
  final logs = <String, Map<int, num>>{};

  /// Makes every write throw, to test rollback.
  bool failWrites = false;

  void _write() {
    if (failWrites) throw StateError('disk full');
  }

  @override
  Future<void> close() async {}

  @override
  Future<List<Tracked>> loadAll() async => [
    for (final c in configs.values) Tracked(c, {...logs[c.id]!}),
  ];

  @override
  Future<List<HabitConfig>> habits() async => configs.values.toList();

  @override
  Future<void> saveHabit(HabitConfig h) async {
    _write();
    configs[h.id] = h;
    logs.putIfAbsent(h.id, () => {});
  }

  @override
  Future<void> replaceAll(List<Tracked> all) async {
    _write();
    configs.clear();
    logs.clear();
    for (final t in all) {
      configs[t.config.id] = t.config;
      logs[t.config.id] = {...t.log};
    }
  }

  @override
  Future<void> removeHabit(String id) async {
    _write();
    configs.remove(id);
    logs.remove(id);
  }

  @override
  Future<void> setValue(String habitId, int day, num? value) async {
    _write();
    value == null ? logs[habitId]!.remove(day) : logs[habitId]![day] = value;
  }

  @override
  Future<Map<int, num>> log(String habitId) async => {...?logs[habitId]};
}

HabitConfig habit(
  String id, {
  String? name,
  Schedule schedule = const Schedule.daily(),
  Goal goal = const Goal(),
  String unit = '',
  int createdDay = testToday - 30,
  int? reminder = 540,
  String flower = 'tulip',
}) => HabitConfig(
  id: id,
  name: name ?? id,
  flowerId: flower,
  schedule: schedule,
  goal: goal,
  unit: unit,
  createdDay: createdDay,
  reminderMinutes: reminder,
);

Tracked tracked(HabitConfig c, [Iterable<int> days = const []]) =>
    Tracked(c, {for (final d in days) d: 1});

List<Override> gardenOverrides({
  List<Tracked> habits = const [],
  int today = testToday,
  FakeGardenDb? db,
  bool unlocked = true,
  Purchases? purchases,
  List<Override> extra = const [],
}) => [
  // Tests assume the unlock is owned unless they say otherwise.
  if (purchases != null)
    purchasesProvider.overrideWithValue(purchases)
  else
    unlockedProvider.overrideWith(() => FixedUnlocked(unlocked)),
  gardenDbProvider.overrideWithValue(db ?? FakeGardenDb(habits)),
  initialHabitsProvider.overrideWithValue(habits),
  todayProvider.overrideWith(() => FixedToday(today)),
  ...extra,
];

/// A container over a [FakeGardenDb] seeded with [habits].
ProviderContainer makeContainer({
  List<Tracked> habits = const [],
  int today = testToday,
  FakeGardenDb? db,
  bool unlocked = true,
  Purchases? purchases,
  List<Override> overrides = const [],
}) {
  final c = ProviderContainer(
    overrides: gardenOverrides(
      habits: habits,
      today: today,
      db: db,
      unlocked: unlocked,
      purchases: purchases,
      extra: overrides,
    ),
  );
  addTearDown(c.dispose);
  return c;
}

/// Flowers animate forever, so never wait for "settled": run 1.2 s of frames
/// (page transitions take up to 0.8 s).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Shows [home] in the app theme on a tall phone-width screen.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget home, {
  List<Tracked> habits = const [],
  FakeGardenDb? db,
  int today = testToday,
  bool dark = false,
  bool unlocked = true,
  Purchases? purchases,
  List<Override> extra = const [],
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: gardenOverrides(
        habits: habits,
        today: today,
        db: db,
        unlocked: unlocked,
        purchases: purchases,
        extra: extra,
      ),
      child: MaterialApp(
        theme: gardenTheme(Brightness.light),
        darkTheme: gardenTheme(Brightness.dark),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: home,
      ),
    ),
  );
  await settle(tester);
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
