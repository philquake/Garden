import 'habit.dart';

enum Tone { warm, smallStep, freshStart }

const _warm = [
  'Your garden is still here, and so are you.',
  'Every garden has quiet seasons. This one is still yours.',
  'The meadow is patient. Take a breath and wander in.',
  'Your flowers are glad you are here.',
  'Slow days are part of growing. Nothing here is going anywhere.',
  'A gentle hello from your garden. No hurry at all.',
  'The sun comes round again tomorrow, and so does a new chance.',
  'Your garden holds everything you have grown so far.',
  'Rest is part of a garden too. Come back when you are ready.',
  'Soft light, soft soil. Your meadow is waiting for you.',
];

const _smallStep = [
  'Even one watering today is enough to start again.',
  'Pick just one flower and give it a little water.',
  'One small drink for one small flower is plenty today.',
  'A single watering is a lovely place to begin.',
  'Start with the easiest flower. The rest can wait.',
  'Two minutes with your garden is more than enough.',
  'Tiny steps still make petals open.',
  'Choose one habit today and give it a sip of water.',
  'One watering, then see how it feels.',
  'A little water now helps a lot over time.',
];

const _freshStart = [
  'Rough weeks happen. Want to give your {flower} a fresh start? '
      'Your history stays.',
  'Your {flower} would welcome a fresh start. Everything you grew is kept.',
  'Ready to begin again with your {flower}? Your history stays safe.',
  'A fresh start for your {flower} is one tap away, and your history stays.',
  'Rough patches pass. Your {flower} can start fresh whenever you like.',
  'Would your {flower} like to begin anew? What you have grown stays.',
  'Sometimes a garden just needs a new beginning. Try one for your {flower}.',
  'Your {flower} is ready when you are. A fresh start keeps your history.',
  'Let your {flower} begin again, gently. Nothing you grew goes away.',
  'A new start for your {flower} could feel good. Your history stays.',
];

/// Deterministic message for [tone]; [seed] picks the variant.
String encouragement(Tone tone, int seed, {String? flower}) {
  final pool = switch (tone) {
    Tone.warm => _warm,
    Tone.smallStep => _smallStep,
    Tone.freshStart => _freshStart,
  };
  final text = pool[seed % pool.length]; // Dart's % is never negative
  final name = (flower == null || flower.trim().isEmpty)
      ? 'flower'
      : flower.trim().toLowerCase();
  return text.replaceAll('{flower}', name);
}

/// True when misses across the live garden add up to at least three.
bool isStruggling(List<Habit> habits) =>
    habits.where((h) => !h.lost).fold(0, (a, h) => a + h.missedSinceWater) >= 3;

({Tone tone, String? habitId, String? flower}) bannerChoice(
  List<Habit> habits,
  int today,
) {
  Habit? best;
  for (final h in habits) {
    if (h.lost || h.declineStep < 3) continue;
    if (best == null ||
        h.declineStep > best.declineStep ||
        (h.declineStep == best.declineStep &&
            h.missedSinceWater > best.missedSinceWater)) {
      best = h;
    }
  }
  if (best != null) {
    return (
      tone: Tone.freshStart,
      habitId: best.id,
      flower: best.flowerId.toLowerCase(),
    );
  }
  return (
    tone: today % 2 == 0 ? Tone.warm : Tone.smallStep,
    habitId: null,
    flower: null,
  );
}
