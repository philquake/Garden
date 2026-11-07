import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/habit.dart';

enum FlowerHealth { healthy, thirsty, wilting, petalLoss }

FlowerHealth healthOf(Habit h) =>
    FlowerHealth.values[h.declineStep.clamp(0, FlowerHealth.values.length - 1)];

const _stages = 5;

/// Frame asset paths per flower, stage and health, with graceful fallback.
class ArtPack {
  ArtPack._(this._frames);

  // flowerId -> stage -> health -> frames (insertion order = pack order).
  final Map<String, Map<int, Map<FlowerHealth, List<String>>>> _frames;

  List<String> get flowerIds => _frames.keys.toList();

  factory ArtPack.fromManifest(Map<String, dynamic> manifest) {
    final frames = <String, Map<int, Map<FlowerHealth, List<String>>>>{};
    manifest.forEach((flower, stages) {
      final byStage = <int, Map<FlowerHealth, List<String>>>{};
      (stages as Map).forEach((stage, states) {
        final s = int.tryParse('$stage');
        if (s == null) return;
        final byHealth = <FlowerHealth, List<String>>{};
        (states as Map).forEach((state, paths) {
          for (final h in FlowerHealth.values) {
            if (h.name == state) {
              byHealth[h] = [for (final p in paths as List) p as String];
            }
          }
        });
        byStage[s] = byHealth;
      });
      frames[flower] = byStage;
    });
    return ArtPack._(frames);
  }

  static Future<ArtPack> load(
    AssetBundle bundle, {
    String pack = 'placeholder',
  }) async {
    final raw = await bundle.loadString('assets/art/$pack/manifest.json');
    return ArtPack.fromManifest(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Built in code; mirrors assets/art/placeholder/manifest.json.
  factory ArtPack.placeholder() {
    const dir = 'assets/art/placeholder';
    final m = <String, dynamic>{};
    for (final f in ['tulip', 'sunflower', 'lavender', 'daisy']) {
      m[f] = {
        for (var s = 0; s < _stages; s++)
          '$s': {
            'healthy': ['$dir/${f}_${s}_healthy.png'],
            if (s == 2 || s == 4) ...{
              'wilting': ['$dir/${f}_${s}_wilting.png'],
              'petalLoss': ['$dir/${f}_${s}_petalLoss.png'],
            },
          },
      };
    }
    return ArtPack.fromManifest(m);
  }

  /// Never throws; empty only if the pack has no frames at all.
  List<String> framesFor(String flowerId, int stage, FlowerHealth health) {
    final first = _frames.keys.isEmpty ? null : _frames.keys.first;
    final found =
        _lookup(flowerId, stage, health) ??
        // Its own harsher frames still beat another flower's.
        _lookup(flowerId, stage, health, harsher: true) ??
        (first == null ? null : _lookup(first, stage, health)) ??
        _anyFrames(flowerId) ??
        (first == null ? null : _anyFrames(first));
    if (found != null) return found;
    return identical(this, _fallback)
        ? const []
        : _fallback.framesFor(flowerId, stage, health);
  }

  static final ArtPack _fallback = ArtPack.placeholder();

  List<String>? _lookup(
    String flower,
    int stage,
    FlowerHealth health, {
    bool harsher = false,
  }) {
    final byStage = _frames[flower];
    if (byStage == null) return null;
    final s = stage.clamp(0, _stages - 1);
    final order = [
      for (var i = s; i >= 0; i--) i,
      for (var i = s + 1; i < _stages; i++) i,
    ];
    final healths = [
      for (var i = health.index; i >= 0; i--) i,
      if (harsher)
        for (var i = health.index + 1; i < FlowerHealth.values.length; i++) i,
    ];
    for (final st in order) {
      for (final i in healths) {
        final f = byStage[st]?[FlowerHealth.values[i]];
        if (f != null && f.isNotEmpty) return f;
      }
    }
    return null;
  }

  List<String>? _anyFrames(String flower) {
    for (final st
        in _frames[flower]?.values ??
            const <Map<FlowerHealth, List<String>>>[]) {
      for (final f in st.values) {
        if (f.isNotEmpty) return f;
      }
    }
    return null;
  }
}
