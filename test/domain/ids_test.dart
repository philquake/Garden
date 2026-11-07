import 'package:flutter_test/flutter_test.dart';
import 'package:garden/domain/ids.dart';

void main() {
  test('ids are 16 hex chars and distinct', () {
    final ids = {for (var i = 0; i < 1000; i++) newHabitId()};
    expect(ids.length, 1000);
    for (final id in ids) {
      expect(id, matches(RegExp(r'^[0-9a-f]{16}$')));
    }
  });
}
