import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/schedule.dart';
import 'package:garden/domain/stats.dart';
import 'package:garden/flower/look.dart';

/// A daily habit created on day 4 with [days] logged, seen on [today].
Stats stats(Iterable<int> days, int today) => computeStats(
  schedule: const Schedule.daily(),
  createdDay: 4,
  log: {for (final d in days) d: 1},
  today: today,
);

List<int> run(int from, int to) => [for (var d = from; d <= to; d++) d];

FlowerLook look(Stats s, {bool done = false, String flower = 'tulip'}) =>
    lookOf(flower, s, doneToday: done);

void main() {
  test('a new habit is a seed that waits expectantly for its first day', () {
    final l = look(stats([], 4));
    expect(l.stage, 0);
    expect(l.face, Face.expectant);
    expect(l.bubble, isTrue);
    expect(l.pose, Pose.upright);
  });

  test('done today: no bubble, the stage face', () {
    final l = look(stats([4, 5, 6], 6), done: true);
    expect(l.bubble, isFalse);
    expect(l.face, Face.sleepy); // stage 0
  });

  test('growth follows qualifying days, full bloom only when formed', () {
    expect(look(stats(run(4, 36), 36), done: true).stage, 2); // 33 days
    final formed = look(stats(run(4, 69), 69), done: true);
    expect(formed.stage, 4);
    expect(formed.face, Face.grin);
  });

  test('one missed day after a good run does not droop the flower', () {
    final l = look(stats(run(4, 23), 25)); // day 24 forgiven, today open
    expect(l.pose, Pose.upright);
    expect(l.face, Face.expectant);
  });

  test('a long gap droops and then slumps it, but it never dies', () {
    final droop = look(stats(run(4, 13), 33));
    expect(droop.pose, Pose.droop);
    expect(droop.face, Face.worried);
    final slump = look(stats(run(4, 13), 60));
    expect(slump.pose, Pose.slump);
    expect(slump.face, Face.sad);
    expect(slump.stage, greaterThanOrEqualTo(0));
  });

  test('doing it today after a long gap makes it hopeful', () {
    final l = look(stats([...run(4, 13), 40], 40), done: true);
    expect(l.face, Face.hopeful);
    expect(l.bubble, isFalse);
  });

  test('an unknown flower id falls back to the daisy', () {
    expect(look(stats([], 4), flower: 'rose').kind, 'daisy');
  });

  test('the picker shows a happy full bloom', () {
    final l = pickerLook('sunflower');
    expect((l.kind, l.stage, l.face), ('sunflower', 4, Face.grin));
  });
}
