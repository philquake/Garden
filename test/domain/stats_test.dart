import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/schedule.dart';
import 'package:garden/domain/stats.dart';

// Day 4 is a Monday (day 0 = Thursday 1970-01-01). Days 0..30 are January.
const mon = 4;

Map<int, num> done(Iterable<int> days) => {for (final d in days) d: 1};

Stats daily(Iterable<int> days, int today, {int created = mon}) =>
    computeStats(
      schedule: const Schedule.daily(),
      createdDay: created,
      log: done(days),
      today: today,
    );

void main() {
  group('daily streak', () {
    test('counts consecutive met days', () {
      expect(daily([4, 5, 6], 6).streak, 3);
    });

    test('an unmet today is pending, not a break', () {
      expect(daily([4, 5, 6], 7).streak, 3);
    });

    test('a miss within the monthly allowance is forgiven and keeps the streak', () {
      final s = daily([4, 6, 7], 7); // day 5 missed
      expect(s.streak, 4);
      expect(s.graceUsed, 1);
    });

    test('a third miss in one month breaks the streak', () {
      // misses on 5, 6, 7; met on 8
      final s = daily([4, 8], 8);
      expect(s.streak, 1);
    });

    test('the allowance resets on the 1st of the next month', () {
      // Jan misses 28, 29, 30 -> 28, 29 forgiven, 30 breaks. Feb 1 (day 31) is
      // met, day 32 missed and forgiven under the fresh allowance.
      final s = daily([...List.generate(24, (i) => 4 + i), 31, 33], 33);
      expect(s.streak, 3);
      expect(s.graceUsed, 1);
    });

    test('best runs are listed longest first', () {
      // 4,5,6 met; 7,8,9 missed (7,8 forgiven, 9 breaks); 10,11 met.
      final s = daily([4, 5, 6, 10, 11], 11);
      expect(s.bestRuns.first.length, greaterThanOrEqualTo(s.bestRuns.last.length));
      expect(s.bestRuns, isNotEmpty);
    });
  });

  group('weekday habit', () {
    test('only its weekday counts and misses are forgiven monthly', () {
      final s = computeStats(
        schedule: Schedule.weekday(1), // Mondays: 4, 11, 18
        createdDay: 4,
        log: done([4, 18]),
        today: 18,
      );
      expect(s.streak, 3); // 11 forgiven
      expect(s.graceUsed, 1);
    });
  });

  group('times a week habit', () {
    test('streak counts consecutive met weeks, no allowance', () {
      final s = computeStats(
        schedule: Schedule.timesPerWeek(2),
        createdDay: 4,
        log: done([4, 5, 11, 12]),
        today: 12,
      );
      expect(s.streak, 2);
      expect(s.graceUsed, 0);
    });

    test('an unmet past week breaks it; the current week is pending', () {
      final s = computeStats(
        schedule: Schedule.timesPerWeek(2),
        createdDay: 4,
        log: done([4, 11]), // week 1 has one, week 2 has one
        today: 12,
      );
      expect(s.streak, 0);
    });

    test('the creation week only asks for the days that are left', () {
      // Created on Saturday (day 9): 2 days left in the week, target 3 -> 2.
      final s = computeStats(
        schedule: Schedule.timesPerWeek(3),
        createdDay: 9,
        log: done([9, 10]),
        today: 11,
      );
      expect(s.streak, 1);
    });
  });

  group('numeric goals', () {
    test('at least: the day counts only when the target is reached', () {
      final s = computeStats(
        schedule: const Schedule.daily(),
        createdDay: 4,
        log: {4: 8, 5: 3, 6: 8},
        today: 6,
        goal: const Goal(target: 8),
      );
      expect(s.totalCompletions, 2);
      expect(s.streak, 3); // day 5 forgiven
    });

    test('at most: an unlogged day is under the limit', () {
      final s = computeStats(
        schedule: const Schedule.daily(),
        createdDay: 4,
        log: {5: 3},
        today: 6,
        goal: const Goal(target: 2, atMost: true),
      );
      expect(s.totalCompletions, 2); // days 4 and 6; day 5 went over
    });
  });

  group('habit formed', () {
    test('after 66 qualifying days', () {
      expect(daily(List.generate(65, (i) => 4 + i), 68).formed, isFalse);
      expect(daily(List.generate(66, (i) => 4 + i), 69).formed, isTrue);
    });

    test('forgiven days count towards it', () {
      // 28 met days and 2 forgiven misses (10 and 11)
      final days = List.generate(30, (i) => 4 + i)..removeWhere((d) => d == 10 || d == 11);
      final s = daily(days, 33);
      expect(s.qualifyingDays, 30);
    });
  });

  group('score', () {
    test('is 0 with no history and rises with completions', () {
      expect(daily([], 4).score, 0);
      expect(daily([4, 5, 6, 7], 7).score, greaterThan(daily([4, 5], 5).score));
    });

    test('drops after a miss beyond the allowance', () {
      final before = daily(List.generate(20, (i) => 4 + i), 23).score;
      // days 24, 25 forgiven, 26, 27 missed
      final after = daily(List.generate(20, (i) => 4 + i), 28).score;
      expect(after, lessThan(before));
    });

    test('stays within 0..1', () {
      final s = daily(List.generate(100, (i) => 4 + i), 103);
      expect(s.score, inInclusiveRange(0, 1));
    });
  });
}
