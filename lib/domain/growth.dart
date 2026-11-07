import 'habit.dart';
import 'rules.dart';

/// 0..4: floor(plantingWaterings / perFourWeeks * 4), in integer maths to
/// avoid float rounding at exact boundaries.
int growthStage(Habit h) => (h.plantingWaterings * 4 ~/ h.schedule.perFourWeeks)
    .clamp(0, Rules.stageCount - 1);
