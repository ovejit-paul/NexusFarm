import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/dates.dart';
import '../../core/format.dart';
import '../models/ledger.dart';
import '../store/farm_store.dart';
import 'ledger_entry_form.dart';
import 'widgets.dart';

/// One account for the whole farm, crops and animals together, a month
/// at a time.
class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  DateTime _month = monthStart(today());

  bool get _isCurrentMonth => _month == monthStart(today());

  @override
  Widget build(BuildContext context) {
    final store = FarmStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final from = _month;
        final to = monthEnd(_month);
        final entries = store.data.ledger.where((e) {
          final d = dayOf(e.date);
          return !d.isBefore(from) && !d.isAfter(to);
        }).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        final summary = summarize(store.data.ledger, from: from, to: to);
        final categories = summary.byCategory.entries.toList()
          ..sort((a, b) => a.key.index.compareTo(b.key.index));

        return Scaffold(
          appBar: AppBar(title: const Text('Farm ledger')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LedgerEntryForm()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () =>
                        setState(() => _month = addMonths(_month, -1)),
                  ),
                  Expanded(
                    child: Text(formatMonth(_month),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _isCurrentMonth
                        ? null
                        : () => setState(() => _month = addMonths(_month, 1)),
                  ),
                ],
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _Total('Income', summary.income, AppColors.success),
                      _Total('Spent', summary.expense, AppColors.danger),
                      _Total('Net', summary.net,
                          summary.net >= 0 ? AppColors.primaryDark : AppColors.danger),
                    ],
                  ),
                ),
              ),
              if (categories.isNotEmpty) ...[
                const SectionLabel('By category'),
                Card(
                  child: Column(
                    children: [
                      for (final c in categories)
                        ListTile(
                          dense: true,
                          title: Text(c.key.label),
                          subtitle: Text('in ${formatTaka(c.value.income)} · '
                              'out ${formatTaka(c.value.expense)}'),
                          trailing: Text(
                            formatTaka(c.value.net),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: c.value.net >= 0
                                  ? AppColors.primaryDark
                                  : AppColors.danger,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SectionLabel('Entries'),
              if (entries.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Nothing this month',
                  message: 'Sales, feed, medicine and spray costs appear here. '
                      'Costs you enter on health and spray records are '
                      'added automatically.',
                ),
              for (final e in entries) _EntryTile(entry: e),
            ],
          ),
        );
      },
    );
  }
}

class _Total extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _Total(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(formatTaka(value),
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _EntryTile extends StatelessWidget {
  final LedgerEntry entry;

  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final income = entry.kind == EntryKind.income;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          income ? Icons.south_west : Icons.north_east,
          color: income ? AppColors.success : AppColors.danger,
        ),
        title: Text(entry.note.isEmpty ? entry.category.label : entry.note),
        subtitle: Text('${entry.category.label} · ${formatDay(entry.date)}'
            '${entry.sourceId != null ? ' · automatic' : ''}'),
        trailing: Text(
          '${income ? '+' : '-'}${formatTaka(entry.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: income ? AppColors.success : AppColors.danger,
          ),
        ),
        onLongPress: () async {
          if (await confirmAction(context,
              title: 'Delete this entry?',
              message: entry.sourceId != null
                  ? 'This cost came from a health or spray record. The '
                      'record itself will stay.'
                  : 'It will be removed from the totals.')) {
            await FarmStore.instance.deleteLedgerEntry(entry.id);
          }
        },
      ),
    );
  }
}
