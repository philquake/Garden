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
