import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';
import '../purchases/purchases.dart';
import 'toast.dart';

const _perks = [
  'Unlimited habits',
  'Every chart and your full history',
  'Export your data as CSV',
  'Back up and move to a new phone',
];

/// Offers the one-time unlock. Only ever opened by a tap on something locked,
/// never at launch. Returns true when the unlock is owned afterwards.
Future<bool> showPaywall(BuildContext context, WidgetRef ref) async {
  ref.read(analyticsProvider).track(AnalyticsEvent.paywallViewed);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _Paywall(),
  );
  return ref.read(unlockedProvider);
}

class _Paywall extends ConsumerStatefulWidget {
  const _Paywall();

  @override
  ConsumerState<_Paywall> createState() => _PaywallState();
}

class _PaywallState extends ConsumerState<_Paywall> {
  bool _busy = false;

  Future<void> _buy() async {
    setState(() => _busy = true);
    PurchaseResult result;
    try {
      result = await ref.read(unlockedProvider.notifier).buy();
    } catch (_) {
      result = PurchaseResult.failed;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case PurchaseResult.unlocked:
        Navigator.pop(context);
      case PurchaseResult.cancelled:
        break;
      case PurchaseResult.failed:
        showToast(context, retryText);
      case PurchaseResult.unavailable:
        showToast(context, "The store isn't available right now.");
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    var found = false;
    try {
      found = await ref.read(unlockedProvider.notifier).restore();
    } catch (_) {
      if (mounted) showToast(context, retryText);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (found) {
      Navigator.pop(context);
    } else {
      showToast(context, 'No earlier purchase found to restore.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = ref.read(purchasesProvider).priceLabel;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unlock Garden', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'One payment, yours for good. No subscription, no account.',
            ),
            const SizedBox(height: 16),
            for (final p in _perks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.check, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(p)),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('unlock-buy'),
                onPressed: _busy ? null : _buy,
                child: Text('Unlock for $price'),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  key: const Key('unlock-restore'),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 48)),
                  onPressed: _busy ? null : _restore,
                  child: const Text('Restore purchase'),
                ),
                TextButton(
                  key: const Key('unlock-later'),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 48)),
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('Not now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Stands in for a locked chart or list: says what it is, offers the unlock.
class LockedCard extends ConsumerWidget {
  const LockedCard({super.key, required this.title, required this.what});
  final String title;
  final String what;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.lock_outline),
              ],
            ),
            const SizedBox(height: 8),
            Text(what),
            const SizedBox(height: 12),
            OutlinedButton(
              key: Key('locked-${title.toLowerCase().replaceAll(' ', '-')}'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: () => showPaywall(context, ref),
              child: const Text('Unlock Garden'),
            ),
          ],
        ),
      ),
    ),
  );
}
