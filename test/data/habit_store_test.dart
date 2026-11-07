import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:garden/data/habit_store.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';

Habit h(String id, {int declineStep = 0}) => Habit.newSeed(
  id: id,
  name: 'n$id',
  flowerId: 'rose',
  schedule: const Schedule.daily(),
  today: 10,
).copyWith(declineStep: declineStep, wateredDays: {8, 9}, reminderMinutes: 480);

Future<(HabitStore, SharedPreferences)> open([
  Map<String, Object> init = const {},
]) async {
  SharedPreferences.setMockInitialValues(init);
  final p = await SharedPreferences.getInstance();
  return (HabitStore(p), p);
}

void main() {
  test('save then load round-trips', () async {
    final (s, _) = await open();
    final hs = [h('a'), h('b', declineStep: 2)];
    await s.save(hs);
    expect(
      s.load().map((x) => x.toJson()).toList(),
      hs.map((x) => x.toJson()).toList(),
    );
  });

  test('empty prefs loads []', () async {
    final (s, _) = await open();
    expect(s.load(), isEmpty);
  });

  test('garbage loads [] and is kept', () async {
    final (s, p) = await open({'habits': 'not json{'});
    expect(s.load(), isEmpty);
    expect(p.getString('habits_corrupt'), 'not json{');
    expect(p.getString('habits'), isNull);
  });

  test('non-list JSON is corrupt', () async {
    final (s, p) = await open({'habits': '{"a":1}'});
    expect(s.load(), isEmpty);
    expect(p.getString('habits_corrupt'), '{"a":1}');
  });

  test('missing required field is corrupt', () async {
    final j = h('a').toJson()..remove('name');
    final (s, p) = await open({
      'habits': jsonEncode([j]),
    });
    expect(s.load(), isEmpty);
    expect(p.getString('habits_corrupt'), isNotNull);
  });

  test('out-of-range declineStep is corrupt', () async {
    final raw = jsonEncode([h('a').toJson(), h('b', declineStep: 4).toJson()]);
    final (s, p) = await open({'habits': raw});
    expect(s.load(), isEmpty);
    expect(p.getString('habits_corrupt'), raw);
  });

  test(
    'a garden saved before reminderBaselineMissed loads and round-trips',
    () async {
      final old = h('a').toJson()..remove('reminderBaselineMissed');
      final (s, _) = await open({
        'habits': jsonEncode([old]),
      });
      final loaded = s.load();
      expect(loaded.single.reminderBaselineMissed, 0);
      await s.save(loaded);
      expect(s.load().single.toJson(), {...old, 'reminderBaselineMissed': 0});
    },
  );

  test('negative reminderBaselineMissed is corrupt', () async {
    final bad = h('a').toJson()..['reminderBaselineMissed'] = -1;
    final (s, p) = await open({
      'habits': jsonEncode([bad]),
    });
    expect(s.load(), isEmpty);
    expect(p.containsKey('habits_corrupt'), isTrue);
  });

  test('duplicate ids are corrupt', () async {
    final (s, _) = await open({
      'habits': jsonEncode([h('a').toJson(), h('a').toJson()]),
    });
    expect(s.load(), isEmpty);
  });

  test('second corrupt load keeps the first copy', () async {
    final (s, p) = await open({'habits': 'first'});
    s.load();
    await p.setString('habits', 'second');
    expect(s.load(), isEmpty);
    expect(p.getString('habits_corrupt'), 'first');
  });

  test('save then load works after corrupt load', () async {
    final (s, _) = await open({'habits': 'bad'});
    s.load();
    await s.save([h('a')]);
    expect(s.load().single.id, 'a');
  });
}
