import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../store/farm_store.dart';
import 'widgets.dart';

/// Copy all farm records out, or restore them from a copy.
///
/// Uses the clipboard because it works on every phone and in a browser
/// without file permissions. A farmer can paste the backup into a note,
/// a message to themselves, or an email — anywhere that outlives the
/// phone.
class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  Future<void> _export(BuildContext context) async {
    await Clipboard.setData(
        ClipboardData(text: FarmStore.instance.exportJson()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Copied. Paste it somewhere safe — a note, or a '
          'message to yourself.'),
    ));
  }

  Future<void> _import(BuildContext context) async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clip?.text?.trim() ?? '';
    if (!context.mounted) return;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Copy a backup first, then tap Restore.'),
      ));
      return;
    }

    final ok = await confirmAction(
      context,
      title: 'Replace all records?',
      message: 'Everything currently in the app will be replaced by the '
          'backup. Export first if you want to keep it.',
      action: 'Replace',
    );
    if (!ok || !context.mounted) return;

    try {
      await FarmStore.instance.importJson(text);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Records restored.')));
    } on FormatException catch (e) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Could not restore'),
          content: Text('${e.message}\n\nYour current records were not changed.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = FarmStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final d = store.data;
        final unreadable = store.unreadableBackup;
        return Scaffold(
          appBar: AppBar(title: const Text('Backup and restore')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    '${d.animals.length} animals and flocks · '
                    '${d.healthEvents.length} health records · '
                    '${d.production.length} production entries · '
                    '${d.cropTreatments.length} sprays · '
                    '${d.ledger.length} ledger entries',
                    style: const TextStyle(height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _export(context),
                icon: const Icon(Icons.copy),
                label: const Text('Copy backup'),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _import(context),
                icon: const Icon(Icons.restore),
                label: const Text('Restore from copied backup'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Records live on this phone only. If the phone is lost or '
                'reset, they go with it unless you keep a backup.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              if (unreadable != null) ...[
                const SizedBox(height: 22),
                const NoticeBox(
                  icon: Icons.error_outline,
                  color: AppColors.danger,
                  title: 'An unreadable copy of old records was kept',
                  body: 'It could not be opened when the app started. Copy '
                      'it and keep it — it may be recoverable.',
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: unreadable));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copied.')));
                          }
                        },
                        child: const Text('Copy it'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          if (await confirmAction(context,
                              title: 'Discard the unreadable copy?',
                              message: 'This cannot be undone.',
                              action: 'Discard')) {
                            await store.clearUnreadableBackup();
                          }
                        },
                        child: const Text('Discard'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
