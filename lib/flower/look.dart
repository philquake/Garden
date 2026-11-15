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

/// The look for [h] on [today]. First match wins: lost, petal loss, wilting,
/// fresh start, wants water, then the growth stage's own face.
FlowerLook lookOf(Habit h, int today) {
  final kind = _kind(h.flowerId);
  if (h.lost) {
    return FlowerLook(kind: kind, stage: 0, face: Face.asleep, faded: true);
  }
  final stage = displayStage(h);
  final wantsWater = needsWaterToday(h, today) || h.declineStep >= 1;
  final (face, pose) = switch (h.declineStep) {
    >= 3 => (Face.sad, Pose.slump),
    2 => (Face.worried, Pose.droop),
    _ when h.declineStep <= 0 && h.freshStartDay >= 0 => (
      Face.hopeful,
      Pose.upright,
    ),
    _ when wantsWater => (Face.expectant, Pose.upright),
    _ => (_stageFaces[stage], Pose.upright),
  };
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
