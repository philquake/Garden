/// 8 -> "8", 2.5 -> "2.5".
String formatNum(num v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
