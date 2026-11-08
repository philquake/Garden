import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/growth.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/schedule.dart';

void main() {
  final bloom = Habit.newSeed(
    id: 'h',
    name: 'Habit',
    flowerId: 'tulip',
    schedule: const Schedule.daily(),
    today: 0,
  ).copyWith(plantingWaterings: 28);

  test('a full bloom is drawn as a bloom', () {
    expect(displayStage(bloom), 4);
  });

  test('a lost flower is drawn as a seed on every screen', () {
    expect(displayStage(bloom.copyWith(lost: true)), 0);
  });
}
