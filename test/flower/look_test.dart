import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/schedule.dart';
import 'package:garden/flower/look.dart';

const _today = 102; // a Monday

/// A daily habit at [stage], watered today unless [dry].
Habit _h({
  int stage = 4,
  bool dry = false,
  int step = 0,
  bool lost = false,
  int fresh = -1,
  String flower = 'tulip',
  Schedule schedule = const Schedule.daily(),
}) =>
    Habit.newSeed(
      id: 'a',
      name: 'Read',
      flowerId: flower,
      schedule: schedule,
      today: 50,
    ).copyWith(
      plantingWaterings: stage * schedule.perWeek,
      wateredDays: dry ? const {} : const {_today},
      declineStep: step,
      lost: lost,
      freshStartDay: fresh,
      evaluatedDay: _today,
    );

void main() {
  test('lost: a faded sleeping seed, whatever it had grown to', () {
    final l = lookOf(_h(lost: true, step: 3, dry: true), _today);
    expect(l.stage, 0);
    expect(l.face, Face.asleep);
    expect(l.pose, Pose.upright);
    expect(l.faded, true);
    expect(l.bubble, false);
  });

  test('petal loss: sad and slumped, with the bubble', () {
    final l = lookOf(_h(step: 3, dry: true), _today);
    expect((l.face, l.pose, l.bubble), (Face.sad, Pose.slump, true));
    expect(l.faded, false);
  });

  test('wilting: worried and drooping, with the bubble', () {
    final l = lookOf(_h(step: 2, dry: true), _today);
    expect((l.face, l.pose, l.bubble), (Face.worried, Pose.droop, true));
  });

  test('decline beats a fresh start', () {
    expect(lookOf(_h(step: 3, fresh: _today), _today).face, Face.sad);
    expect(lookOf(_h(step: 2, fresh: _today), _today).face, Face.worried);
  });

  test('fresh start: hopeful, and still shows it is due', () {
    final l = lookOf(_h(fresh: _today, dry: true), _today);
    expect((l.face, l.pose, l.bubble), (Face.hopeful, Pose.upright, true));
  });

  test('hopeful ends once the flower is thirsty again', () {
    expect(lookOf(_h(fresh: 99, step: 1), _today).face, Face.expectant);
  });

  test('a fresh-start day in the future (clock moved back) still works', () {
    expect(lookOf(_h(fresh: _today + 5), _today).face, Face.hopeful);
  });

  test('thirsty: expectant with the bubble even when watered today', () {
    final l = lookOf(_h(step: 1), _today);
    expect((l.face, l.bubble), (Face.expectant, true));
  });

  test('due today: expectant with the bubble', () {
    final l = lookOf(_h(dry: true), _today);
    expect((l.face, l.pose, l.bubble), (Face.expectant, Pose.upright, true));
  });

  test('watered and healthy: the face follows the growth stage', () {
    const faces = [
      Face.sleepy,
      Face.curious,
      Face.curious,
      Face.content,
      Face.grin,
    ];
    for (var s = 0; s < 5; s++) {
      final l = lookOf(_h(stage: s), _today);
      expect(l.stage, s);
      expect(l.face, faces[s], reason: 'stage $s');
      expect(l.bubble, false);
      expect(l.pose, Pose.upright);
    }
  });

  test('a weekday habit on another day is not due', () {
    final l = lookOf(_h(schedule: Schedule.weekday(3), dry: true), _today);
    expect((l.face, l.bubble), (Face.grin, false));
  });

  test('a times-a-week habit that met its target is not due', () {
    final h = _h(schedule: Schedule.timesPerWeek(2))
        .copyWith(wateredDays: {_today, _today + 1});
    expect(lookOf(h, _today + 2).bubble, false);
  });

  test('an unknown flower kind is drawn as a daisy', () {
    expect(lookOf(_h(flower: 'orchid'), _today).kind, 'daisy');
    expect(lookOf(_h(flower: 'lavender'), _today).kind, 'lavender');
    expect(pickerLook('orchid').kind, 'daisy');
  });

  test('picker look: a happy full bloom', () {
    expect(
      pickerLook('tulip'),
      const FlowerLook(kind: 'tulip', stage: 4, face: Face.grin),
    );
  });

  test('kinds keep their order', () {
    expect(flowerKinds, ['tulip', 'sunflower', 'lavender', 'daisy']);
  });
}
