import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/habit_config.dart';
import 'package:garden/domain/stats.dart';
import 'package:garden/ui/history.dart';

import '../support.dart';

void main() {
  test('dates: day 0 is 1 Jan 1970, and month starts line up', () {
    expect(shortDate(0), '1 Jan');
    expect(shortDate(testToday), '4 Oct');
    expect(monthStartDay(1970, 2), 31);
    expect(monthStartDay(1970, 0), -31); // rolls back to Dec 1969
  });

  test('week buckets: 12 of them, the last one ends today', () {
    final t = tracked(habit('a'), [testToday - 1, testToday]);
    final b = buckets(t, testToday, Range.week);
    expect(b.length, 12);
    expect(b.last.end, testToday);
    // Day 20000 is a Friday, so the week started on day 19996.
    expect(b.last.start, 19996);
    expect(b.last.met, 2);
    expect(b[b.length - 2].end, 19995);
  });

  test('month buckets cover the calendar months without gaps', () {
    final t = tracked(habit('a'), [testToday]);
    final b = buckets(t, testToday, Range.month);
    expect(b.length, 12);
    for (var i = 1; i < b.length; i++) {
      expect(b[i].start, b[i - 1].end + 1);
    }
    expect(b.last.start, monthStartDay(2024, 10));
    expect(b.last.met, 1);
  });

  test('year buckets: five years', () {
    expect(buckets(tracked(habit('a')), testToday, Range.year).length, 5);
  });

  test('score points are 0 before the habit existed and rise with use', () {
    final days = [for (var d = testToday - 20; d <= testToday; d++) d];
    final t = tracked(habit('a', createdDay: testToday - 20), days);
    final b = buckets(t, testToday, Range.week);
    expect(b.first.score, 0);
    expect(b.last.score, greaterThan(b[b.length - 2].score));
  });

  test('marks: met, partial, forgiven; nothing for a missed day', () {
    final t = tracked(habit('a', createdDay: 100), [100, 102]);
    final marks = marksOf(t, t.stats(103));
    expect(marks[100], Mark.met);
    expect(marks[101], Mark.forgiven);
    expect(marks[102], Mark.met);
    expect(marks[103], isNull);
  });

  test('a numeric day short of the target is partial', () {
    final h = habit('a', goal: const Goal(target: 8), createdDay: 100);
    final t = Tracked(h, {100: 3, 101: 8});
    final marks = marksOf(t, t.stats(101));
    expect(marks[100], Mark.partial);
    expect(marks[101], Mark.met);
  });
}
