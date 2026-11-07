import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which encouragement banner was dismissed this app run (in memory), as
/// [bannerKey]; null when none was.
final bannerDismissedProvider = NotifierProvider<BannerDismissed, String?>(
  BannerDismissed.new,
);

class BannerDismissed extends Notifier<String?> {
  @override
  String? build() => null;
  void dismiss(String key) => state = key;
}

/// `fresh:<habitId>` for a fresh-start banner, `general` otherwise.
String bannerKey(String? freshStartHabitId) =>
    freshStartHabitId == null ? 'general' : 'fresh:$freshStartHabitId';

/// After a dismissal only a fresh-start banner for another flower shows.
bool bannerHidden(String? dismissed, String key) =>
    dismissed != null && (dismissed == key || !key.startsWith('fresh:'));
