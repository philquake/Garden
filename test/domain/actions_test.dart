import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/actions.dart';
import 'package:garden/domain/growth.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/neglect.dart';
import 'package:garden/domain/rules.dart';
import 'package:garden/domain/schedule.dart';

Habit seed([Schedule s = const Schedule.daily()]) => Habit.newSeed(
  id: 'a',
  name: 'Read',
  flowerId: 'rose',
  schedule: s,
  today: 100,
);

void main() {
  group('water', () {
    test('double tap same day counts once', () {
      final once = water(seed(), 100);
      final twice = water(once, 100);
      expect(twice.plantingWaterings, 1);
      expect(twice.wateredDays, {100});
    });

    test('watering an unscheduled day counts', () {
      final h = water(seed(Schedule.timesPerWeek(1)), 103);
      expect(h.plantingWaterings, 1);
      expect(h.wateredDays, {103});
    });

    test('back-fill 3 days ok, 4 days throws, future throws', () {
      final h = seed();
      expect(water(h, 110, forDay: 107).wateredDays, contains(107));
      expect(() => water(h, 110, forDay: 106), throwsArgumentError);
      expect(() => water(h, 110, forDay: 111), throwsArgumentError);
    });

    test('repeated back-fill counts once', () {
      final h = water(water(seed(), 105, forDay: 103), 105, forDay: 103);
      expect(h.plantingWaterings, 1);
    });

    test('reduces declineStep by exactly one and zeroes misses', () {
      final neglected = advance(seed(), 109);
      expect(neglected.declineStep, 3);
      final h = water(neglected, 109);
      expect(h.declineStep, 2);
      expect(h.missedSinceWater, 0);
      expect(h.lastWaterDay, 109);
    });

    test('lastWaterDay never moves backwards on back-fill', () {
      final h = water(water(seed(), 110), 110, forDay: 108);
      expect(h.lastWaterDay, 110);
      expect(h.wateredDays, {108, 110});
    });

    test('lost habit throws', () {
      final lost = advance(seed(), 130);
      expect(lost.lost, isTrue);
      expect(() => water(lost, 130), throwsStateError);
    });
  });

  group('freshStart', () {
    test('healthy habit throws', () {
      expect(() => freshStart(seed(), 100), throwsStateError);
    });

    test('keeps stage and wateredDays, clears decline', () {
      var h = seed();
      for (var d = 100; d < 104; d++) {
        h = water(h, d);
      }
      h = advance(h, 115);
      expect(h.declineStep, 3);
      final f = freshStart(h, 115);
      expect(f.declineStep, 0);
      expect(f.missedSinceWater, 0);
      expect(f.lastWaterDay, 115);
      expect(f.evaluatedDay, 115);
      expect(f.lost, isFalse);
      expect(growthStage(f), growthStage(h));
      expect(f.wateredDays, h.wateredDays);
      expect(f.plantingWaterings, h.plantingWaterings);
    });

    test('allowed from day 14 without water, before petal loss', () {
      final h = advance(seed(Schedule.weekday(1)), 114);
      expect(h.declineStep, lessThan(3));
      final f = freshStart(h, 114);
      expect([f.declineStep, f.missedSinceWater, f.lastWaterDay], [0, 0, 114]);
    });

    test('throws at 13 days without water before petal loss', () {
      final h = advance(seed(Schedule.weekday(1)), 113);
      expect(h.declineStep, lessThan(3));
      expect(() => freshStart(h, 113), throwsStateError);
    });

    test('available on every warning day, as the warning copy promises', () {
      for (final w in Rules.warnDays) {
        expect(freshStart(seed(Schedule.weekday(1)), 100 + w).lost, isFalse);
      }
    });

    test('lost habit throws', () {
      final lost = advance(seed(), 130);
      expect(() => freshStart(lost, 130), throwsStateError);
    });
  });

  group('replant', () {
    test('non-lost habit throws', () {
      expect(() => replant(seed(), 100), throwsStateError);
    });

    test('keeps wateredDays, resets stage, bumps plantingNumber', () {
      var h = seed();
      for (var d = 100; d < 110; d++) {
        h = water(h, d);
      }
      h = advance(h, 150);
      expect(h.lost, isTrue);
      final r = replant(h, 150);
      expect(r.wateredDays, h.wateredDays);
      expect(growthStage(r), 0);
      expect(r.plantingWaterings, 0);
      expect(r.plantingNumber, h.plantingNumber + 1);
      expect(r.lost, isFalse);
      expect(r.declineStep, 0);
      expect(r.missedSinceWater, 0);
      expect(r.lastWaterDay, 150);
      expect(r.evaluatedDay, 150);
    });
  });

  group('editSchedule', () {
    test('mid-week edit then advance same day yields no new misses', () {
      final h = editSchedule(
        seed(Schedule.timesPerWeek(3)),
        const Schedule.daily(),
        103,
      );
      expect(h.schedule, const Schedule.daily());
      expect(h.evaluatedDay, 103);
      final a = advance(h, 103);
      expect(a.missedSinceWater, h.missedSinceWater);
      expect(a.declineStep, h.declineStep);
    });

    test('does not erase misses accrued before the edit', () {
      final h = editSchedule(seed(), Schedule.weekday(3), 105);
      expect(h.missedSinceWater, 4); // planting day is grace
      expect(h.declineStep, advance(seed(), 105).declineStep);
    });
  });

  group('fix round 1', () {
    test(
      'water on a habit that goes lost through advance throws, no change',
      () {
        final h = seed();
        expect(() => water(h, 130), throwsStateError);
        expect(h.wateredDays, isEmpty);
        expect(h.plantingWaterings, 0);
      },
    );

    test('backward clock: editSchedule does not double count', () {
      final h = advance(seed(), 105);
      final e = editSchedule(h, const Schedule.daily(), 103);
      expect(e.evaluatedDay, 105);
      final end = advance(e, 108);
      final expected = advance(h, 108);
      expect(end.missedSinceWater, expected.missedSinceWater);
      expect(end.declineStep, expected.declineStep);
      expect(end.evaluatedDay, greaterThanOrEqualTo(h.evaluatedDay));
    });

    test('clock behind: freshStart restarts from today, never frozen', () {
      final h = advance(seed(), 109);
      final f = freshStart(h, 105);
      expect([f.evaluatedDay, f.lastWaterDay, f.declineStep], [105, 105, 0]);
      // Not frozen: later days count again from the restart.
      expect(advance(f, 108).missedSinceWater, 2);
    });

    test('a far-future clock does not freeze a replanted flower', () {
      final lost = advance(seed(), 5000);
      expect(lost.lost, isTrue);
      final r = replant(lost, 120);
      expect([r.evaluatedDay, r.lastWaterDay, r.lost], [120, 120, false]);
      expect(advance(r, 123).declineStep, 1);
    });

    test(
      'back-fill before lastWaterDay at step 2 drops to 1, keeps lastWaterDay',
      () {
        final h = advance(seed(), 105).copyWith(lastWaterDay: 104);
        expect(h.declineStep, 2);
        final w = water(h, 105, forDay: 102);
        expect(w.declineStep, 1);
        expect(w.lastWaterDay, 104);
      },
    );
  });

  group('audit fixes', () {
    test('editSchedule keeps the growth stage for every schedule pair', () {
      final schedules = [
        const Schedule.daily(),
        for (var n = 1; n <= 7; n++) Schedule.timesPerWeek(n),
        Schedule.weekday(1),
      ];
      for (final from in schedules) {
        for (final to in schedules) {
          for (var w = 0; w <= 60; w++) {
            final h = seed(from).copyWith(plantingWaterings: w);
            expect(
              growthStage(editSchedule(h, to, 100)),
              growthStage(h),
              reason: '$w waterings, ${from.kind} -> ${to.kind}',
            );
          }
        }
      }
    });

    test('a late log of day 28 saves a flower that day 30 would lose', () {
      final h = seed(); // last watered day 100
      final saved = water(h, 130, forDay: 128);
      expect(saved.lost, isFalse);
      expect(saved.lastWaterDay, 128);
      // Watering today, 30 days dry, is still too late.
      expect(() => water(h, 130), throwsStateError);
    });

    test(
      'extra waterings in a week add no growth beyond the weekly target',
      () {
        // Day 102 is a Monday; a once-a-week habit asks for 1 watering a week.
        var h = seed(Schedule.weekday(1));
        for (final d in [103, 104, 105]) {
          h = water(h, 105, forDay: d);
        }
        expect(h.wateredDays, {103, 104, 105});
        expect(h.plantingWaterings, 1);
        expect(growthStage(h), 1);
        // The next week earns credit again.
        expect(water(h, 110).plantingWaterings, 2);
      },
    );
  });
}
