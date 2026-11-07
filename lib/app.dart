import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/garden_controller.dart';
import 'ui/habit_form.dart';
import 'ui/habit_screen.dart';
import 'ui/meadow_screen.dart';
import 'ui/theme.dart';

class GardenApp extends StatelessWidget {
  const GardenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: gardenTheme(),
      debugShowCheckedModeBanner: false,
      title: 'Garden',
      home: Consumer(
        builder: (context, ref, _) {
          // The navigator sits below the MaterialApp, so push via this context.
          void push(Widget w) =>
              Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => w));
          return MeadowScreen(
            onPlant: () => push(const HabitForm()),
            onOpenHabit: (id) => push(
              HabitScreen(
                habitId: id,
                onEdit: () {
                  // Read at tap time so the form sees the habit's current state.
                  final h = ref
                      .read(gardenProvider)
                      .where((e) => e.id == id)
                      .firstOrNull;
                  if (h != null) push(HabitForm(existing: h));
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
