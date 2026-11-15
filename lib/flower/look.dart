import '../domain/due.dart';
import '../domain/growth.dart';
import '../domain/habit.dart';

/// Flower kinds, in picker order.
const flowerKinds = ['tulip', 'sunflower', 'lavender', 'daisy'];

enum Face {
  asleep,
  sad,
  worried,
  hopeful,
  expectant,
  sleepy,
  curious,
  content,
  grin,
}

enum Pose { upright, droop, slump }

/// Everything the painter needs to draw one flower at rest.
class FlowerLook {
  const FlowerLook({
    required this.kind,
    required this.stage,
    required this.face,
    this.pose = Pose.upright,
    this.bubble = false,
    this.faded = false,
  });

  /// Always one of [flowerKinds].
  final String kind;

  /// 0 seed .. 4 full bloom.
  final int stage;
  final Face face;
  final Pose pose;

  /// Water-drop thought bubble: the flower wants water.
  final bool bubble;

  /// A lost flower, drawn faint.
  final bool faded;

  @override
  bool operator ==(Object other) =>
      other is FlowerLook &&
      other.kind == kind &&
      other.stage == stage &&
      other.face == face &&
      other.pose == pose &&
      other.bubble == bubble &&
      other.faded == faded;

  @override
  int get hashCode => Object.hash(kind, stage, face, pose, bubble, faded);

  @override
  String toString() =>
      'FlowerLook($kind, $stage, $face, $pose, $bubble, $faded)';
}

String _kind(String flowerId) =>
    flowerKinds.contains(flowerId) ? flowerId : 'daisy';

const _stageFaces = [
  Face.sleepy,
  Face.curious,
  Face.curious,
  Face.content,
  Face.grin,
];

/// The look for [h] on [today]. First match wins: lost, watered today while
/// recovering, petal loss, wilting, fresh start, wants water, then the growth
/// stage's own face.
FlowerLook lookOf(Habit h, int today) {
  final kind = _kind(h.flowerId);
  if (h.lost) {
    return FlowerLook(kind: kind, stage: 0, face: Face.asleep, faded: true);
  }
  final stage = displayStage(h);
  final step = h.declineStep;
  // Nothing more can be done today once it is watered, so the pang ends: the
  // body still shows the decline, the face looks up, and the bubble goes.
  final watered = h.wateredDays.contains(today);
  final wantsWater = !watered && (needsWaterToday(h, today) || step >= 1);
  final pose = step >= 3
      ? Pose.slump
      : step == 2
      ? Pose.droop
      : Pose.upright;
  final Face face;
  if (watered && step >= 1) {
    face = Face.hopeful;
  } else if (step >= 3) {
    face = Face.sad;
  } else if (step == 2) {
    face = Face.worried;
  } else if (step <= 0 && h.freshStartDay >= 0) {
    face = Face.hopeful;
  } else if (wantsWater) {
    face = Face.expectant;
  } else {
    face = _stageFaces[stage];
  }
  return FlowerLook(
    kind: kind,
    stage: stage,
    face: face,
    pose: pose,
    bubble: wantsWater,
  );
}

/// The flower picker shows each kind as a happy full bloom.
FlowerLook pickerLook(String kind) =>
    FlowerLook(kind: _kind(kind), stage: 4, face: Face.grin);
