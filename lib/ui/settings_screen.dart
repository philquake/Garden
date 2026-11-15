import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';
import '../domain/day.dart';
import '../export/backup.dart';
import '../export/csv.dart';
import '../export/file_transfer.dart';
import '../purchases/purchases.dart';
import '../state/garden_controller.dart';
import 'paywall.dart';
import 'theme.dart';
import 'toast.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Export and backup need the unlock: offers it, and says whether to go on.
  Future<bool> _unlocked(BuildContext context, WidgetRef ref) async {
    if (ref.read(unlockedProvider)) return true;
    return await showPaywall(context, ref);
  }

  Future<void> _share(
    BuildContext context,
    WidgetRef ref,
    List<ExportFile> files,
    AnalyticsEvent event,
  ) async {
    try {
      await ref.read(fileTransferProvider).share(files);
      ref.read(analyticsProvider).track(event);
    } catch (_) {
      if (context.mounted) showToast(context, retryText);
    }
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    if (!await _unlocked(context, ref) || !context.mounted) return;
    final today = ref.read(todayProvider);
    await _share(
      context,
      ref,
      csvFiles(ref.read(gardenProvider), today),
      AnalyticsEvent.exportUsed,
    );
  }

  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    if (!await _unlocked(context, ref) || !context.mounted) return;
    final today = ref.read(todayProvider);
    final text = encodeBackup(ref.read(gardenProvider), today);
    await _share(context, ref, [
      ExportFile('garden-backup-${isoDate(today)}.json', text),
    ], AnalyticsEvent.backupUsed);
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    if (!await _unlocked(context, ref) || !context.mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from a backup?'),
        content: const Text(
          'This replaces everything in Garden on this phone with the backup. '
          'Your current habits and history will be gone.',
        ),
        actions: [
          TextButton(
            key: const Key('cancel-restore'),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-restore'),
            style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Choose a file'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    try {
      final text = await ref.read(fileTransferProvider).pickBackup();
      if (text == null) return; // cancelled
      final habits = decodeBackup(text);
      await ref.read(gardenProvider.notifier).replaceAll(habits);
      if (context.mounted) {
        final n = habits.length;
        showToast(context, 'Restored $n ${n == 1 ? 'habit' : 'habits'}.');
      }
    } on BackupException catch (e) {
      if (context.mounted) showToast(context, e.message);
    } catch (_) {
      if (context.mounted) showToast(context, retryText);
    }
  }

  Future<void> _restorePurchase(BuildContext context, WidgetRef ref) async {
    try {
      final found = await ref.read(unlockedProvider.notifier).restore();
      if (context.mounted) {
        showToast(
          context,
          found
              ? 'Your purchase is restored.'
              : 'No earlier purchase found to restore.',
        );
      }
    } catch (_) {
      if (context.mounted) showToast(context, retryText);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(unlockedProvider);
    final consent = ref.watch(analyticsConsentProvider) ?? false;
    final theme = Theme.of(context);
    final lock = unlocked ? null : const Icon(Icons.lock_outline);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _Group(
            color: unlocked ? null : theme.colorScheme.tertiaryContainer,
            children: [
              if (unlocked)
                const ListTile(
                  key: Key('unlock-status'),
                  leading: Icon(Icons.verified_outlined),
                  title: Text('Garden is unlocked'),
                  subtitle: Text('Thank you. It is yours for good.'),
                )
              else
                ListTile(
                  key: const Key('unlock-tile'),
                  leading: const Icon(Icons.lock_open_outlined),
                  title: const Text('Unlock Garden'),
                  subtitle: Text(
                    'One payment, ${ref.read(purchasesProvider).priceLabel}',
                  ),
                  onTap: () => showPaywall(context, ref),
                ),
              ListTile(
                key: const Key('restore-tile'),
                leading: const Icon(Icons.restore),
                title: const Text('Restore purchase'),
                onTap: () => _restorePurchase(context, ref),
              ),
            ],
          ),
          _Header('Your data'),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              'Garden keeps everything on this phone. Your phone\'s own backup '
              '(Google or iCloud) usually moves it to a new phone for you. To '
              'move between Android and iPhone, or to keep a copy of your own, '
              'use a backup file.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          _Group(
            children: [
              ListTile(
                key: const Key('export-csv'),
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('Export as CSV'),
                subtitle: const Text(
                  'For spreadsheets: every day of every habit',
                ),
                trailing: lock,
                onTap: () => _exportCsv(context, ref),
              ),
              ListTile(
                key: const Key('backup'),
                leading: const Icon(Icons.save_alt_outlined),
                title: const Text('Back up to a file'),
                subtitle: const Text(
                  'Everything, to restore on this or a new phone',
                ),
                trailing: lock,
                onTap: () => _backup(context, ref),
              ),
              ListTile(
                key: const Key('restore-backup'),
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('Restore from a backup'),
                trailing: lock,
                onTap: () => _restoreBackup(context, ref),
              ),
            ],
          ),
          _Header('Privacy'),
          _Group(
            children: [
              SwitchListTile(
                key: const Key('analytics-switch'),
                title: const Text('Share anonymous usage'),
                subtitle: const Text(
                  'Counts only, like which screens get used. Never your habits, '
                  'names or notes.',
                ),
                value: consent,
                onChanged: (v) =>
                    ref.read(analyticsConsentProvider.notifier).set(v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// Related settings on one card, split by thin lines.
class _Group extends StatelessWidget {
  const _Group({required this.children, this.color});
  final List<Widget> children;
  final Color? color;

  @override
  Widget build(BuildContext context) => SectionCard(
    color: color,
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(indent: 56),
          children[i],
        ],
      ],
    ),
  );
}
