import 'package:flutter_test/flutter_test.dart';
import 'package:garden/ui/meadow_painter.dart';

void main() {
  test('neighbouring flower boxes (120 wide) never overlap sideways', () {
    for (var seed = 0; seed < 300; seed++) {
      for (var i = 0; i < 7; i++) {
        final a = flowerPosition('id$seed-$i', i, 1350, 800);
        final b = flowerPosition('id$seed-${i + 1}', i + 1, 1350, 800);
        expect(b.dx - a.dx, greaterThanOrEqualTo(120));
      }
    }
  });
}
