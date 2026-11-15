import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/flower/flower_view.dart';
import 'package:garden/flower/look.dart';

const _grin = FlowerLook(kind: 'daisy', stage: 4, face: Face.grin);
const _seed = FlowerLook(kind: 'daisy', stage: 0, face: Face.sleepy);

Widget _host(
  FlowerLook look, {
  double size = 240,
  int delight = 0,
  bool still = false,
}) => MediaQuery(
  data: MediaQueryData(disableAnimations: still),
  child: Center(
    child: FlowerView(look: look, size: size, seed: 7, delightTrigger: delight),
  ),
);

void main() {
  for (final size in [56.0, 64.0, 240.0]) {
    testWidgets('every look paints at $size px', (tester) async {
      for (final kind in flowerKinds) {
        for (var stage = 0; stage < 5; stage++) {
          for (final face in Face.values) {
            for (final pose in Pose.values) {
              for (final bubble in [false, true]) {
                final look = FlowerLook(
                  kind: kind,
                  stage: stage,
                  face: face,
                  pose: pose,
                  bubble: bubble,
                );
                await tester.pumpWidget(_host(look, size: size));
                await tester.pump(const Duration(milliseconds: 700));
                expect(tester.takeException(), isNull, reason: '$look');
              }
            }
          }
        }
      }
      expect(tester.getSize(find.byType(FlowerView)), Size(size, size));
    });
  }

  testWidgets('a seed paints, moving and still', (tester) async {
    await tester.pumpWidget(_host(_seed));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(_host(_seed, still: true));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('moves when motion is allowed', (tester) async {
    await tester.pumpWidget(_host(_grin));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('reduce motion: nothing animates, even on events', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_grin, still: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(_host(_grin, still: true, delight: 1));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);

    const bud = FlowerLook(kind: 'daisy', stage: 2, face: Face.curious);
    await tester.pumpWidget(_host(bud, still: true, delight: 1));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a flower lost mid-growth settles without error', (tester) async {
    const bud = FlowerLook(kind: 'daisy', stage: 3, face: Face.content);
    await tester.pumpWidget(_host(bud));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(_host(_grin));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(_host(_seed));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce motion switched on during a delight stops it', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_grin));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(_host(_grin, delight: 1));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(_host(_grin, delight: 1, still: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a delight plays through and motion resumes after stillness', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_grin, still: true));
    await tester.pumpWidget(_host(_grin));
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(_host(_grin, delight: 1));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing stops the clock', (tester) async {
    await tester.pumpWidget(_host(_grin));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
