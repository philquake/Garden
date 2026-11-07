import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/messages.dart';
import 'package:garden/domain/schedule.dart';

Habit _h(
  String id, {
  int missed = 0,
  int step = 0,
  bool lost = false,
  String flower = 'Tulip',
}) => Habit.newSeed(
  id: id,
  name: id,
  flowerId: flower,
  schedule: const Schedule.daily(),
  today: 100,
).copyWith(missedSinceWater: missed, declineStep: step, lost: lost);

Set<String> _all(Tone t, {String? flower}) => {
  for (var i = 0; i < 200; i++) encouragement(t, i, flower: flower),
};

void main() {
  test('each tone has at least 10 distinct variants', () {
    for (final t in Tone.values) {
      expect(_all(t, flower: 'rose').length, greaterThanOrEqualTo(10));
    }
  });

  test('deterministic, varied, negative seeds fine', () {
    for (final t in Tone.values) {
      expect(encouragement(t, 3), encouragement(t, 3));
      expect(encouragement(t, 0), isNot(encouragement(t, 1)));
      expect(encouragement(t, -1), isNotEmpty);
      expect(encouragement(t, -7), encouragement(t, -7));
    }
  });

  test('exact first entries', () {
    expect(
      encouragement(Tone.warm, 0),
      'Your garden is still here, and so are you.',
    );
    expect(
      encouragement(Tone.smallStep, 0),
      'Even one watering today is enough to start again.',
    );
    expect(
      encouragement(Tone.freshStart, 0, flower: 'Tulip'),
      'Rough weeks happen. Want to give your tulip a fresh start? '
      'Your history stays.',
    );
  });

  test('freshStart fallback word and no placeholder survives', () {
    expect(encouragement(Tone.freshStart, 0), contains('your flower '));
    expect(
      encouragement(Tone.freshStart, 0, flower: '  '),
      contains('your flower '),
    );
    for (final t in Tone.values) {
      for (final f in [null, 'Rose', '']) {
        for (final m in _all(t, flower: f)) {
          expect(m, isNot(contains('{')));
        }
      }
    }
  });

  test('no guilt words', () {
    const banned = [
      'fail',
      'lazy',
      'behind',
      'missed',
      'late',
      'bad',
      'should',
      'guilt',
      'streak',
      'punish',
      'lost',
      'give up',
    ];
    for (final t in Tone.values) {
      for (final f in [null, 'Rose', 'Sunflower']) {
        for (final m in _all(t, flower: f)) {
          for (final w in banned) {
            expect(m.toLowerCase(), isNot(contains(w)), reason: m);
          }
        }
      }
    }
  });

  test('isStruggling threshold and lost exclusion', () {
    expect(isStruggling([_h('a', missed: 2)]), isFalse);
    expect(isStruggling([_h('a', missed: 1), _h('b', missed: 2)]), isTrue);
    expect(isStruggling([_h('a', missed: 3)]), isTrue);
    expect(
      isStruggling([_h('a', missed: 2), _h('b', missed: 5, lost: true)]),
      isFalse,
    );
  });

  test('bannerChoice', () {
    final c = bannerChoice([
      _h('a', missed: 3),
      _h('b', missed: 4, step: 3, flower: 'Rose'),
    ], 4);
    expect(c.tone, Tone.freshStart);
    expect(c.habitId, 'b');
    expect(c.flower, 'rose');
    expect(bannerChoice([_h('a', step: 3, lost: true)], 4).tone, Tone.warm);
    expect(bannerChoice([_h('a', missed: 3)], 4).tone, Tone.warm);
    expect(bannerChoice([_h('a', missed: 3)], 5).tone, Tone.smallStep);
  });

  test('bannerSeed halves warm/smallStep days, keeps freshStart', () {
    expect(bannerSeed(Tone.warm, 20000), 10000);
    expect(bannerSeed(Tone.smallStep, 20001), 10000);
    expect(bannerSeed(Tone.smallStep, -1), -1);
    expect(bannerSeed(Tone.warm, -2), -1);
    expect(bannerSeed(Tone.freshStart, 7), 7);
  });

  test('every warm and smallStep variant is reachable via the banner', () {
    final warm = <String>{};
    final small = <String>{};
    for (var day = 0; day < 40; day++) {
      final c = bannerChoice([_h('a', missed: 3)], day);
      final m = encouragement(c.tone, bannerSeed(c.tone, day));
      (c.tone == Tone.warm ? warm : small).add(m);
    }
    expect(warm.length, 10);
    expect(small.length, 10);
    expect(
      small,
      contains('Even one watering today is enough to start again.'),
    );
    expect(warm, contains('Your garden is still here, and so are you.'));
  });

  test('a flower waiting 14+ days shows the banner and gets freshStart', () {
    Habit dry(String id, int last, {String flower = 'Tulip'}) =>
        _h(id, flower: flower).copyWith(lastWaterDay: last);
    final c = bannerChoice([dry('a', 90), dry('b', 85, flower: 'Rose')], 100);
    expect(c.tone, Tone.freshStart);
    expect(c.habitId, 'b');
    expect(c.flower, 'rose');
    // Petal loss still comes first.
    expect(bannerChoice([dry('a', 80), _h('p', step: 3)], 100).habitId, 'p');
    expect(showsBanner([dry('a', 86)], 100), isTrue);
    expect(showsBanner([dry('a', 87)], 100), isFalse);
    expect(showsBanner([dry('a', 80).copyWith(lost: true)], 100), isFalse);
  });
}
