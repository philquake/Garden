import 'dart:math';

import '../domain/stats.dart';

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
  });

  /// Always one of [flowerKinds].
  final String kind;

  /// 0 seed .. 4 full bloom.
  final int stage;
  final Face face;
  final Pose pose;

  /// Water-drop thought bubble: the flower wants water.
  final bool bubble;

  @override
  bool operator ==(Object other) =>
      other is FlowerLook &&
      other.kind == kind &&
      other.stage == stage &&
      other.face == face &&
      other.pose == pose &&
      other.bubble == bubble;

  @override
  int get hashCode => Object.hash(kind, stage, face, pose, bubble);

  @override
  String toString() => 'FlowerLook($kind, $stage, $face, $pose, $bubble)';
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

/// The look for a habit. Flowers never die: growth follows qualifying days
/// towards "habit formed", and mood follows the recent score, so one missed
/// day does not wilt it.
FlowerLook lookOf(String flowerId, Stats s, {required bool doneToday}) {
  final kind = _kind(flowerId);
  final stage = min((s.growth * 4).floor(), 4);
  // A young habit's score is still climbing from zero, so it is not a mood.
  final established = s.totalCompletions >= 5;
  final Face face;
  var pose = Pose.upright;
  if (established && s.score < 0.15) {
    pose = Pose.slump;
    face = doneToday ? Face.hopeful : Face.sad;
  } else if (established && s.score < 0.35) {
    pose = Pose.droop;
    face = doneToday ? Face.hopeful : Face.worried;
  } else if (s.due) {
    face = Face.expectant;
  } else {
    face = s.formed ? Face.grin : _stageFaces[stage];
  }
  return FlowerLook(
    kind: kind,
    stage: stage,
    face: face,
    pose: pose,
    bubble: s.due && !doneToday,
  );
}

/// The flower picker shows each kind as a happy full bloom.
FlowerLook pickerLook(String kind) =>
    FlowerLook(kind: _kind(kind), stage: 4, face: Face.grin);
