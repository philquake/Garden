import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden/art/art_pack.dart';
import 'package:garden/domain/habit.dart';
import 'package:garden/domain/schedule.dart';

void main() {
  final manifest = <String, dynamic>{
    'rose': {
      '2': {
        'healthy': ['r2h_a', 'r2h_b'],
        'petalLoss': ['r2p'],
      },
      '4': {
        'healthy': ['r4h'],
      },
    },
    'fern': {
      '0': {
        'healthy': ['f0h'],
      },
    },
  };

  test('fromManifest parses multiple frames per state', () {
    final p = ArtPack.fromManifest(manifest);
    expect(p.flowerIds, ['rose', 'fern']);
    expect(p.framesFor('rose', 2, FlowerHealth.healthy), ['r2h_a', 'r2h_b']);
    expect(p.framesFor('rose', 2, FlowerHealth.petalLoss), ['r2p']);
  });

  test('missing wilting frame falls back to healthy of same stage', () {
    final p = ArtPack.fromManifest(manifest);
    expect(p.framesFor('rose', 2, FlowerHealth.wilting), ['r2h_a', 'r2h_b']);
    expect(p.framesFor('rose', 4, FlowerHealth.wilting), ['r4h']);
  });

  test('missing stage falls back to lower then higher stage', () {
    final p = ArtPack.fromManifest(manifest);
    expect(p.framesFor('rose', 3, FlowerHealth.healthy), ['r2h_a', 'r2h_b']);
    expect(p.framesFor('rose', 0, FlowerHealth.healthy), ['r2h_a', 'r2h_b']);
  });

  test('unknown flower uses the first flower and never throws', () {
    final p = ArtPack.fromManifest(manifest);
    expect(p.framesFor('nope', 2, FlowerHealth.healthy), ['r2h_a', 'r2h_b']);
    expect(
      ArtPack.fromManifest({}).framesFor('x', 9, FlowerHealth.wilting),
      isNotNull,
    );
  });

  test('placeholder has 4 flowers and non-empty frames everywhere', () {
    final p = ArtPack.placeholder();
    expect(p.flowerIds, ['tulip', 'sunflower', 'lavender', 'daisy']);
    for (final f in p.flowerIds) {
      for (var s = 0; s < 5; s++) {
        for (final h in FlowerHealth.values) {
          expect(p.framesFor(f, s, h), isNotEmpty);
        }
      }
    }
  });

  test('shipped manifest parses and every file exists', () {
    final json = jsonDecode(
      File('assets/art/placeholder/manifest.json').readAsStringSync(),
    );
    final p = ArtPack.fromManifest(json as Map<String, dynamic>);
    expect(p.flowerIds, isNotEmpty);
    for (final f in p.flowerIds) {
      for (var s = 0; s < 5; s++) {
        for (final h in FlowerHealth.values) {
          for (final path in p.framesFor(f, s, h)) {
            expect(File(path).existsSync(), isTrue, reason: path);
          }
        }
      }
    }
    for (final f in ArtPack.placeholder().flowerIds) {
      for (var s = 0; s < 5; s++) {
        for (final h in FlowerHealth.values) {
          for (final path in ArtPack.placeholder().framesFor(f, s, h)) {
            expect(File(path).existsSync(), isTrue, reason: path);
          }
        }
      }
    }
  });

  test('healthOf maps declineStep', () {
    Habit h(int d) => Habit.newSeed(
      id: 'a',
      name: 'a',
      flowerId: 'tulip',
      schedule: const Schedule.daily(),
      today: 0,
    ).copyWith(declineStep: d);
    expect([for (var d = 0; d < 4; d++) healthOf(h(d))], FlowerHealth.values);
  });

  test('load propagates a missing manifest so callers can fall back', () {
    expect(ArtPack.load(_MissingBundle(), pack: 'nope'), throwsA(anything));
  });
}

class _MissingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => throw FlutterError('missing $key');
}
