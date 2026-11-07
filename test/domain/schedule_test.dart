import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/schedule.dart';

void main() {
  test('perFourWeeks', () {
    expect(const Schedule.daily().perFourWeeks, 28);
    expect(Schedule.timesPerWeek(3).perFourWeeks, 12);
    expect(Schedule.weekday(2).perFourWeeks, 4);
  });

  test('json round-trip preserves kind and parameters', () {
    for (final s in [
      Schedule.daily(),
      Schedule.timesPerWeek(5),
      Schedule.weekday(7),
    ]) {
      final back = Schedule.fromJson(s.toJson());
      expect(back, s);
      expect(back.hashCode, s.hashCode);
      expect(back.kind, s.kind);
    }
    expect(Schedule.timesPerWeek(2), isNot(Schedule.timesPerWeek(3)));
  });

  test('invalid values throw ArgumentError', () {
    expect(() => Schedule.timesPerWeek(0), throwsArgumentError);
    expect(() => Schedule.timesPerWeek(8), throwsArgumentError);
    expect(() => Schedule.weekday(0), throwsArgumentError);
    expect(() => Schedule.weekday(8), throwsArgumentError);
    expect(
      () => Schedule.fromJson({'kind': 'timesPerWeek', 'n': 9}),
      throwsArgumentError,
    );
    expect(() => Schedule.fromJson({'kind': 'bogus'}), throwsArgumentError);
  });
}
