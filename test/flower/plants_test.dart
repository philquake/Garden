import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garden/flower/look.dart';
import 'package:garden/flower/plants.dart';
import 'package:garden/ui/theme.dart';
import 'package:flutter/material.dart';

void main() {
  test('thirty plants, each with a unique id, in four groups', () {
    expect(plants, hasLength(30));
    expect(plants.map((p) => p.id).toSet(), hasLength(30));
    expect(flowerKinds, plants.map((p) => p.id).toList());
    for (final g in PlantGroup.values) {
      expect(plants.where((p) => p.group == g), isNotEmpty, reason: '$g');
    }
    expect(plants.first.id, 'tulip'); // the default for a new habit
  });

  test('every plant has all five growth images on disk', () {
    for (final p in plants) {
      for (var stage = 0; stage < 5; stage++) {
        final f = File('assets/plants/${p.id}_$stage.png');
        expect(f.existsSync(), isTrue, reason: f.path);
      }
    }
  });

  test('every plant has a chart colour for both themes', () {
    for (final p in plants) {
      expect(flowerColor(p.id, Brightness.light), p.light);
      expect(flowerColor(p.id, Brightness.dark), p.dark);
    }
    expect(flowerColor('unknown', Brightness.light), plantOf('daisy')!.light);
  });
}
