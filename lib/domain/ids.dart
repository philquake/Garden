import 'dart:math';

int _last = 0;

/// 16 lowercase hex chars: 12 from the clock in microseconds (bumped so it is
/// strictly increasing within a run), 4 random.
String newHabitId([Random? random]) {
  final r = random ?? Random();
  var t = DateTime.now().microsecondsSinceEpoch;
  if (t <= _last) t = _last + 1;
  _last = t;
  return (t & 0xFFFFFFFFFFFF).toRadixString(16).padLeft(12, '0') +
      r.nextInt(0x10000).toRadixString(16).padLeft(4, '0');
}

/// Stable 32-bit hash (FNV-1a), so a habit's flower always sways the same way.
int stableHash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}
