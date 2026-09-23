import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/dates.dart';
import '../../core/format.dart';
import '../../services/session.dart';
import '../logic/agenda.dart';
import '../models/ledger.dart';
import '../store/farm_store.dart';
import 'animal_detail_screen.dart';
import 'animal_form_screen.dart';
import 'crop_log_screen.dart';
import 'crop_treatment_form.dart';
import 'ledger_entry_form.dart';
import 'widgets.dart';

/// The one screen that answers "what do I need to do, and what must I
/// not do?" across crops and animals together.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = FarmStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final data = store.data;
        final now = today();
        final agenda = buildAgenda(data, now);
        final urgent =
            agenda.where((i) => i.priority == AgendaPriority.urgent).toList();
        final soon =
            agenda.where((i) => i.priority == AgendaPriority.soon).toList();
        final info =
            agenda.where((i) => i.priority == AgendaPriority.info).toList();
        final month =
            summarize(data.ledger, from: monthStart(now), to: monthEnd(now));
        final heads = data.animals.fold<int>(0, (s, a) => s + a.headCount);
        final name = Session.instance.farmerName;

        return Scaffold(
          appBar: AppBar(title: const Text('Today')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _quickAdd(context),
            icon: const Icon(Icons.add),
            label: const Text('Record'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text(name.isEmpty ? 'Good day' : 'Good day, $name',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(formatDay(now),
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Stat(label: 'Animals', value: '$heads'),
                  const SizedBox(width: 10),
                  _Stat(
                    label: 'On hold',
                    value: '${activeHoldCount(data, now)}',
                    color: activeHoldCount(data, now) > 0
                        ? AppColors.danger
                        : null,
                  ),
                  const SizedBox(width: 10),
                  _Stat(
                    label: 'Net, ${formatMonth(now).split(' ').first}',
                    value: formatTaka(month.net),
                    color: month.net < 0 ? AppColors.danger : null,
                  ),
                ],
              ),
              if (store.loadError != null) ...[
                const SizedBox(height: 14),
                NoticeBox(
                  icon: Icons.error_outline,
                  color: AppColors.danger,
                  title: 'Records could not be read',
                  body: store.loadError,
                ),
              ],
              if (agenda.isEmpty)
                EmptyState(
                  icon: Icons.check_circle_outline,
                  title: data.isEmpty ? 'Welcome to NexusFarm' : 'All clear',
                  message: data.isEmpty
                      ? 'Add your animals, record sprays on your crops, and '
                          'everything that needs attention will show here.'
                      : 'Nothing is due and nothing is on hold.',
                ),
              if (urgent.isNotEmpty) ...[
                const SectionLabel('Needs attention'),
                for (final i in urgent) _AgendaTile(item: i),
              ],
              if (soon.isNotEmpty) ...[
                const SectionLabel('Coming up'),
                for (final i in soon) _AgendaTile(item: i),
              ],
              if (info.isNotEmpty) ...[
                const SectionLabel('Missing records'),
                for (final i in info) _AgendaTile(item: i),
              ],
            ],
          ),
        );
      },
    );
  }

  void _quickAdd(BuildContext context) {
    void go(Widget page) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.pets_outlined),
              title: const Text('Add an animal or flock'),
              onTap: () => go(const AnimalFormScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.sanitizer_outlined),
              title: const Text('Record a crop spray'),
              onTap: () => go(const CropTreatmentForm()),
            ),
            ListTile(
              leading: const Icon(Icons.north_east),
              title: const Text('Record an expense'),
              onTap: () => go(const LedgerEntryForm()),
            ),
            ListTile(
              leading: const Icon(Icons.south_west),
              title: const Text('Record income'),
              onTap: () =>
                  go(const LedgerEntryForm(initialKind: EntryKind.income)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE3E8E1)),
          ),
          child: Column(
            children: [
              FittedBox(
                child: Text(value,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: color ?? AppColors.primaryDark)),
              ),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
}

class _AgendaTile extends StatelessWidget {
  final AgendaItem item;

  const _AgendaTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (item.kind) {
      AgendaKind.withdrawal => (Icons.block, AppColors.danger),
      AgendaKind.harvestHold => (Icons.do_not_disturb_on_outlined, AppColors.danger),
      AgendaKind.overdue => (Icons.vaccines_outlined, AppColors.danger),
      AgendaKind.dueSoon => (Icons.event_outlined, AppColors.warning),
      AgendaKind.missingRecords => (Icons.help_outline, AppColors.textSecondary),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(item.title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
        subtitle: Text(item.detail, style: const TextStyle(fontSize: 12.5)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          final Widget page = item.animalId != null
              ? AnimalDetailScreen(animalId: item.animalId!)
              : const CropLogScreen();
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
      ),
    );
  }
}
