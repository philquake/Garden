import 'dart:convert';

import '../domain/habit_config.dart';
import '../domain/ids.dart';
import '../domain/schedule.dart';
import '../domain/stats.dart';

const backupVersion = 1;

/// Why a backup could not be restored, in words fit to show.
class BackupException implements Exception {
  const BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Integrity check over the payload text (catches truncation and edits; it is
/// not a security measure).
String backupChecksum(String data) =>
    stableHash(data).toRadixString(16).padLeft(8, '0');

/// The whole garden as one file: habits, settings and every logged day. The
/// payload is kept as a string so the checksum covers exactly what was
/// written, and catches a file that was cut short or edited.
String encodeBackup(List<Tracked> habits, int today) {
  final payload = jsonEncode({
    'version': backupVersion,
    'exportedDay': today,
    'habits': [
      for (final t in habits)
        {
          'id': t.config.id,
          'name': t.config.name,
          'flowerId': t.config.flowerId,
          'schedule': t.config.schedule.toJson(),
          'target': t.config.goal.target,
          'atMost': t.config.goal.atMost,
          'unit': t.config.unit,
          'createdDay': t.config.createdDay,
          'reminderMinutes': t.config.reminderMinutes,
          'log': {for (final e in t.log.entries) '${e.key}': e.value},
        },
    ],
  });
  return jsonEncode({
    'garden_backup': backupVersion,
    'checksum': backupChecksum(payload),
    'data': payload,
  });
}

T _need<T>(Object? v, String what) {
  if (v is T) return v;
  throw BackupException('This backup is incomplete ($what).');
}

num _number(Object? v, String what) {
  final n = _need<num>(v, what);
  if (!n.isFinite || n < 0) {
    throw BackupException('This backup has a bad number ($what).');
  }
  return n;
}

/// Reads a backup made by [encodeBackup]. Anything unexpected becomes a
/// [BackupException]; a partly valid file is never half-restored.
List<Tracked> decodeBackup(String text) {
  try {
    final envelope = jsonDecode(text);
    if (envelope is! Map || envelope['garden_backup'] is! int) {
      throw const BackupException('That file is not a Garden backup.');
    }
    final version = envelope['garden_backup'] as int;
    if (version > backupVersion) {
      throw const BackupException(
        'This backup was made by a newer version of Garden. Update the app and try again.',
      );
    }
    final data = _need<String>(envelope['data'], 'data');
    if (envelope['checksum'] != backupChecksum(data)) {
      throw const BackupException(
        'This backup looks damaged, so nothing was changed.',
      );
    }
    final payload = _need<Map>(jsonDecode(data), 'contents');
    final ids = <String>{};
    final out = <Tracked>[];
    for (final raw in _need<List>(payload['habits'], 'habits')) {
      final h = _need<Map>(raw, 'a habit');
      final id = _need<String>(h['id'], 'id');
      final name = _need<String>(h['name'], 'name').trim();
      if (id.isEmpty || name.isEmpty) {
        throw const BackupException('This backup has a habit with no name.');
      }
      if (!ids.add(id)) {
        throw const BackupException('This backup lists a habit twice.');
      }
      final Schedule schedule;
      try {
        schedule = Schedule.fromJson(
          Map<String, dynamic>.from(_need<Map>(h['schedule'], 'schedule')),
        );
      } on ArgumentError {
        throw const BackupException(
          'This backup has a schedule I do not understand.',
        );
      }
      final created = _need<int>(h['createdDay'], 'created day');
      final reminder = h['reminderMinutes'];
      if (reminder != null &&
          (reminder is! int || reminder < 0 || reminder > 1439)) {
        throw const BackupException('This backup has a bad reminder time.');
      }
      final config = HabitConfig(
        id: id,
        name: name,
        flowerId: _need<String>(h['flowerId'], 'flower'),
        schedule: schedule,
        goal: Goal(
          target: _number(h['target'], 'target'),
          atMost: _need<bool>(h['atMost'], 'direction'),
        ),
        unit: _need<String>(h['unit'], 'unit'),
        createdDay: created,
        reminderMinutes: reminder as int?,
      );
      if (config.goal.target == 0 && !config.goal.atMost) {
        throw const BackupException('This backup has a goal of zero.');
      }
      final log = <int, num>{};
      for (final e in _need<Map>(h['log'], 'history').entries) {
        final day = int.tryParse('${e.key}');
        if (day == null) {
          throw const BackupException('This backup has a bad date.');
        }
        log[day] = _number(e.value, 'value');
      }
      out.add(Tracked(config, log));
    }
    return out;
  } on BackupException {
    rethrow;
  } catch (_) {
    throw const BackupException('That file is not a Garden backup.');
  }
}
