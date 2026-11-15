import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../data/garden_db.dart';
import '../demo/demo.dart';
import '../domain/day.dart';
import '../domain/habit_config.dart';
import 'widget_data.dart';

const _providers = [
  'com.phillipcole.garden.SingleWidgetProvider',
  'com.phillipcole.garden.RowWidgetProvider',
];

Future<GardenDb> openGardenDb() async => GardenDb.open(
  databaseFactory,
  p.join(await getDatabasesPath(), demoMode ? 'garden_demo.db' : 'garden.db'),
);

/// Hands the widgets the current tiles and asks them to redraw.
Future<void> pushWidgets(List<Tracked> habits, int today) async {
  await HomeWidget.saveWidgetData('snapshot', snapshotJson(habits, today));
  for (final name in _providers) {
    await HomeWidget.updateWidget(qualifiedAndroidName: name);
  }
}

/// Runs in a background isolate when a widget tile is tapped (garden://tap?id=…).
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  final id = uri?.queryParameters['id'];
  if (uri?.host != 'tap' || id == null) return;
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openGardenDb();
  try {
    final today = dayIndex(DateTime.now());
    final all = await db.loadAll();
    final t = all.where((t) => t.config.id == id).firstOrNull;
    if (t == null) return; // habit was deleted
    final next = tapValue(t.config, t.log[today]);
    await db.setValue(id, today, next);
    await pushWidgets(await db.loadAll(), today);
  } finally {
    await db.close();
  }
}
