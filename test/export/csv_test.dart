import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/habit_config.dart';
import 'package:garden/domain/schedule.dart';
import 'package:garden/domain/stats.dart';
import 'package:garden/export/csv.dart';

import '../support.dart';

List<String> lines(String csv) =>
    csv.split('\r\n').where((l) => l.isNotEmpty).toList();

void main() {
  group('csvCell', () {
    test('plain text is left alone', () {
      expect(csvCell('Read'), 'Read');
    });

    test('commas, quotes and line breaks are quoted', () {
      expect(csvCell('a,b'), '"a,b"');
      expect(csvCell('say "hi"'), '"say ""hi"""');
      expect(csvCell('two\nlines'), '"two\nlines"');
    });

    test('a leading formula character is neutralised', () {
      for (final bad in ['=SUM(A1)', '+1', '-1', '@x']) {
        expect(csvCell(bad), startsWith("'"));
      }
      expect(csvCell('=1,2'), '"\'=1,2"');
    });

    test('unicode survives', () {
      expect(csvCell('Café ☕'), 'Café ☕');
    });
  });

  group('completions.csv', () {
    test('has a header and one row per day since creation', () {
      final t = tracked(habit('a', name: 'Read', createdDay: testToday - 2), [
        testToday - 2,
        testToday,
      ]);
      expect(lines(completionsCsv([t], testToday)), [
        'habit,date,completed,value,note',
        'Read,2024-10-02,1,,',
        'Read,2024-10-03,0,,',
        'Read,2024-10-04,1,,',
      ]);
    });

    test('number habits carry their value; unlogged days are blank', () {
      final h = habit(
        'w',
        name: 'Water',
        goal: const Goal(target: 8),
        createdDay: testToday - 2,
      );
      final t = Tracked(h, {testToday - 2: 8, testToday - 1: 2.5});
      expect(lines(completionsCsv([t], testToday)).skip(1), [
        'Water,2024-10-02,1,8,',
        'Water,2024-10-03,0,2.5,',
        'Water,2024-10-04,0,,',
      ]);
    });

    test('"completed" follows the same rule as the streaks', () {
      final coffee = habit(
        'c',
        name: 'Coffee',
        goal: const Goal(target: 2, atMost: true),
        createdDay: testToday - 1,
      );
      final weekly = habit(
        'g',
        name: 'Gym',
        schedule: Schedule.timesPerWeek(3),
        createdDay: testToday - 1,
      );
      final rows = lines(
        completionsCsv([
          Tracked(coffee, {testToday - 1: 3}),
          tracked(weekly, [testToday]),
        ], testToday),
      );
      expect(rows, [
        'habit,date,completed,value,note',
        'Coffee,2024-10-03,0,3,',
        'Coffee,2024-10-04,1,,', // nothing logged: under the limit
        'Gym,2024-10-03,0,,',
        'Gym,2024-10-04,1,,',
      ]);
    });

    test('several habits, in creation order, and none gives only a header', () {
      expect(lines(completionsCsv([], testToday)).length, 1);
      final rows = lines(
        completionsCsv([
          tracked(habit('a', name: 'A', createdDay: testToday)),
          tracked(habit('b', name: 'B', createdDay: testToday)),
        ], testToday),
      );
      expect(rows.skip(1).map((r) => r[0]), ['A', 'B']);
    });

    test('a name with a comma stays one field', () {
      final t = tracked(habit('a', name: 'Eat, sleep', createdDay: testToday));
      expect(
        lines(completionsCsv([t], testToday)).last,
        startsWith('"Eat, sleep",'),
      );
    });

    test('a long history is complete', () {
      final t = tracked(habit('a', createdDay: testToday - 999));
      expect(lines(completionsCsv([t], testToday)).length, 1001);
    });
  });

  group('habits.csv', () {
    test('describes each habit and where it stands', () {
      final daily = tracked(
        habit('a', name: 'Read', createdDay: testToday - 4),
        [testToday - 2, testToday - 1, testToday],
      );
      final water = habit(
        'w',
        name: 'Water',
        goal: const Goal(target: 8),
        unit: 'glasses',
        schedule: Schedule.timesPerWeek(5),
        createdDay: testToday - 3,
      );
      final call = habit(
        'c',
        name: 'Call mum',
        schedule: Schedule.weekday(7),
        createdDay: testToday - 3,
      );
      final rows = lines(
        habitsCsv([
          daily,
          Tracked(water, {testToday: 8}),
          tracked(call),
        ], testToday),
      );
      expect(
        rows[0],
        'name,created,schedule,goal,unit,current_streak,streak_unit,habit_formed,total_completions',
      );
      expect(rows[1], 'Read,2024-09-30,Every day,yes/no,,3,days,no,3');
      expect(
        rows[2],
        'Water,2024-10-01,5 times a week,at least 8,glasses,0,weeks,no,1',
      );
      expect(rows[3], startsWith('Call mum,2024-10-01,Every Sunday,yes/no,'));
    });
  });

  test('files are named by date and start with a byte order mark', () {
    final files = csvFiles([tracked(habit('a'))], testToday);
    expect(files.map((f) => f.name), [
      'garden-completions-2024-10-04.csv',
      'garden-habits-2024-10-04.csv',
    ]);
    expect(
      files.every((f) => f.contents.startsWith(String.fromCharCode(0xFEFF))),
      isTrue,
    );
  });
}
