import '../domain/day.dart';
import '../domain/format.dart';
import '../domain/habit_config.dart';
import '../domain/schedule.dart';
import '../domain/stats.dart';

/// A file ready to share.
class ExportFile {
  const ExportFile(this.name, this.contents);
  final String name;
  final String contents;
}

/// Quotes a field for CSV. A leading = + - @ would run as a formula in a
/// spreadsheet, so it gets an apostrophe in front.
String csvCell(String v) {
  var s = v;
  if (s.isNotEmpty && '=+-@\t\r'.contains(s[0])) s = "'$s";
  if (s.contains(RegExp(r'[",\r\n]'))) s = '"${s.replaceAll('"', '""')}"';
  return s;
}

String _row(List<String> cells) => '${cells.map(csvCell).join(',')}\r\n';

String scheduleText(Schedule s) => switch (s.kind) {
  ScheduleKind.daily => 'Every day',
  ScheduleKind.timesPerWeek => '${s.value} times a week',
  ScheduleKind.weekday => 'Every ${dayNames[s.value - 1]}',
};

String goalText(HabitConfig c) => c.isYesNo
    ? 'yes/no'
    : '${c.goal.atMost ? 'at most' : 'at least'} ${formatNum(c.goal.target)}';

/// One row per habit per day, from the day it was created to [today]:
/// habit, date, completed (1/0), value (blank for yes/no, or when nothing was
/// logged), note (always empty: Garden has no notes yet).
String completionsCsv(List<Tracked> habits, int today) {
  final out = StringBuffer(
    _row(['habit', 'date', 'completed', 'value', 'note']),
  );
  for (final t in habits) {
    final c = t.config;
    for (var d = c.createdDay; d <= today; d++) {
      final v = t.log[d];
      out.write(
        _row([
          c.name,
          isoDate(d),
          dayMet(c.schedule, c.goal, t.log, d) ? '1' : '0',
          c.isYesNo || v == null ? '' : formatNum(v),
          '',
        ]),
      );
    }
  }
  return out.toString();
}

/// One row per habit: its settings and where it stands today.
String habitsCsv(List<Tracked> habits, int today) {
  final out = StringBuffer(
    _row([
      'name',
      'created',
      'schedule',
      'goal',
      'unit',
      'current_streak',
      'streak_unit',
      'habit_formed',
      'total_completions',
    ]),
  );
  for (final t in habits) {
    final c = t.config;
    final s = t.stats(today);
    out.write(
      _row([
        c.name,
        isoDate(c.createdDay),
        scheduleText(c.schedule),
        goalText(c),
        c.unit,
        '${s.streak}',
        c.schedule.kind == ScheduleKind.timesPerWeek ? 'weeks' : 'days',
        s.formed ? 'yes' : 'no',
        '${s.totalCompletions}',
      ]),
    );
  }
  return out.toString();
}

/// A byte order mark makes Excel read the names as UTF-8.
final _bom = String.fromCharCode(0xFEFF);

List<ExportFile> csvFiles(List<Tracked> habits, int today) {
  final stamp = isoDate(today);
  return [
    ExportFile(
      'garden-completions-$stamp.csv',
      _bom + completionsCsv(habits, today),
    ),
    ExportFile('garden-habits-$stamp.csv', _bom + habitsCsv(habits, today)),
  ];
}
