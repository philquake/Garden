import 'package:flutter/widgets.dart';

/// Reduced motion asked for by the app's MediaQuery or the platform (iOS
/// Reduce Motion, which MediaQuery's disableAnimations does not cover).
bool reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .reduceMotion;
