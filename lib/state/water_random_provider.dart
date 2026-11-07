import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source of chance for the watering effect; tests override it.
final waterRandomProvider = Provider<Random>((ref) => Random());
