import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Encouragement banners dismissed this app run (in memory), as [bannerKey]s.
final bannerDismissedProvider = NotifierProvider<BannerDismissed, Set<String>>(
  BannerDismissed.new,
);

class BannerDismissed extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};
  void dismiss(String key) => state = {...state, key};
}

/// `fresh:<habitId>` for a fresh-start banner, `general` otherwise.
String bannerKey(String? freshStartHabitId) =>
    freshStartHabitId == null ? 'general' : 'fresh:$freshStartHabitId';

/// After a dismissal only a fresh-start banner for another flower shows.
bool bannerHidden(Set<String> dismissed, String key) =>
    dismissed.contains(key) ||
    (dismissed.isNotEmpty && !key.startsWith('fresh:'));
