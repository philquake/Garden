import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/rules.dart';

void main() {
  test('rule constants', () {
    expect(Rules.dayStartHour, 3);
    expect(Rules.habitCap, 8);
    expect(Rules.backfillDays, 3);
    expect(Rules.fullBloomWeeks, 4);
    expect(Rules.wiltMissed, 2);
    expect(Rules.wiltDays, 4);
    expect(Rules.petalMissed, 3);
    expect(Rules.petalDays, 8);
    expect(Rules.lostDays, 30);
    expect(Rules.warnDays, [14, 21, 27]);
    expect(Rules.stageCount, 5);
  });
}
