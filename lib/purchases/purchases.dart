import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';

/// Habits a free user can keep.
const freeHabitLimit = 3;

/// Shown until the store reports the real, local price.
const fallbackPrice = r'$9.99';

enum PurchaseResult { unlocked, cancelled, failed, unavailable }

/// The one-time unlock. The real implementation talks to the app stores (via
/// RevenueCat); tests use a fake. No accounts: the store restores purchases.
abstract class Purchases {
  /// Whether this install already owns the unlock.
  Future<bool> isUnlocked();

  /// The price to show, in the store's currency, or [fallbackPrice].
  String get priceLabel;

  Future<PurchaseResult> buy();

  /// True when a previous purchase was found and restored.
  Future<bool> restore();
}

/// Used until the store is connected: nothing can be bought or restored.
class NoStorePurchases implements Purchases {
  const NoStorePurchases();

  @override
  Future<bool> isUnlocked() async => false;

  @override
  String get priceLabel => fallbackPrice;

  @override
  Future<PurchaseResult> buy() async => PurchaseResult.unavailable;

  @override
  Future<bool> restore() async => false;
}

final purchasesProvider = Provider<Purchases>(
  (ref) => const NoStorePurchases(),
);

/// Thrown when a free install tries to add a habit past [freeHabitLimit].
class FreeLimitReached implements Exception {
  const FreeLimitReached();

  @override
  String toString() => 'Free garden holds $freeHabitLimit habits';
}

/// Whether the one-time unlock is owned.
final unlockedProvider = NotifierProvider<Unlocked, bool>(Unlocked.new);

class Unlocked extends Notifier<bool> {
  Purchases get _purchases => ref.read(purchasesProvider);

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    try {
      final owned = await _purchases.isUnlocked();
      if (ref.mounted && owned) state = true;
    } catch (_) {
      // Stay locked; the store may simply be unreachable right now.
    }
  }

  Future<PurchaseResult> buy() async {
    final r = await _purchases.buy();
    if (r == PurchaseResult.unlocked && ref.mounted) {
      state = true;
      ref.read(analyticsProvider).track(AnalyticsEvent.purchase);
    }
    return r;
  }

  Future<bool> restore() async {
    final found = await _purchases.restore();
    if (found && ref.mounted) state = true;
    return found;
  }
}
