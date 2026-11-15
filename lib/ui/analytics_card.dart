import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';

/// Asked once, as a card in the list rather than a pop-up, and never again
/// after either answer. The same choice lives in Settings.
class AnalyticsAskCard extends ConsumerWidget {
  const AnalyticsAskCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(analyticsConsentProvider) != null) {
      return const SizedBox.shrink();
    }
    final consent = ref.read(analyticsConsentProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        key: const Key('analytics-ask'),
        color: Theme.of(context).colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Help improve Garden?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Share anonymous counts, like which screens get used. Never '
                'your habits, names or notes. You can change this in Settings.',
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('analytics-no'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                    onPressed: () => consent.set(false),
                    child: const Text('No thanks'),
                  ),
                  FilledButton(
                    key: const Key('analytics-yes'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                    onPressed: () => consent.set(true),
                    child: const Text('Share'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
