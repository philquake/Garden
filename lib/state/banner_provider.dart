import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the encouragement banner was dismissed this app run (in memory).
final bannerDismissedProvider = NotifierProvider<BannerDismissed, bool>(
  BannerDismissed.new,
);

class BannerDismissed extends Notifier<bool> {
  @override
  bool build() => false;
  void dismiss() => state = true;
}
