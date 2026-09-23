import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/dates.dart';
import '../../core/format.dart';
import '../logic/agenda.dart';
import '../logic/livestock_logic.dart';
import '../models/livestock.dart';
import '../store/farm_store.dart';
import 'animal_form_screen.dart';
import 'health_event_form_screen.dart';
import 'production_dialog.dart';
import 'widgets.dart';

class AnimalDetailScreen extends StatelessWidget {
  final String animalId;

  const AnimalDetailScreen({super.key, required this.animalId});

  @override
  Widget build(BuildContext context) {
    final store = FarmStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final data = store.data;
        final animal = data.animalById(animalId);
        if (animal == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('This record has been removed.')),
          );
        }

        final now = today();
        final holds = withdrawalsFor(animal, data.healthEvents, now);
        final schedule = scheduleFor(animal, data.healthEvents, now)
          ..sort((a, b) => a.state.index.compareTo(b.state.index));
        final history = data.eventsFor(animal.id).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        final product = animal.species.dailyProduct;
        final logs = data.productionFor(animal.id).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        final week = productionTotals(data, animal.id, product, now);

        return Scaffold(
          appBar: AppBar(
            title: Text(animal.name),
            actions: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AnimalFormScreen(existing: animal)),
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(context, animal),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              _Header(animal: animal),
              const SizedBox(height: 14),
              for (final h in holds)
                NoticeBox(
                  icon: Icons.block,
                  color: AppColors.danger,
                  title: h.product.holdAction(animal.name),
                  body: 'Withdrawal after ${h.cause.name} on '
                      '${formatDay(h.cause.date)}. Safe from '
                      '${formatDay(h.safeFrom)} — ${h.daysLeft(now)} '
                      '${h.daysLeft(now) == 1 ? 'day' : 'days'} left.',
                ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                HealthEventFormScreen(animal: animal)),
                      ),
                      icon: const Icon(Icons.medical_services_outlined),
                      label: const Text('Health record'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => showProductionDialog(context, animal),
                      icon: Icon(product == Product.milk
                          ? Icons.water_drop_outlined
                          : Icons.egg_outlined),
                      label: Text('Log ${product.label.toLowerCase()}'),
                    ),
                  ),
                ],
              ),
              const SectionLabel('Vaccination and deworming'),
              for (final s in schedule) _ScheduleTile(status: s, now: now),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Intervals are typical values. Confirm them with your '
                  'livestock officer.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ),
              SectionLabel('${product.label} · last 7 days'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: _Figure(
                          label: 'Usable',
                          value: '${formatQty(week.usable)} ${product.unit}',
                          color: AppColors.primaryDark,
                        ),
                      ),
                      Expanded(
                        child: _Figure(
                          label: 'Discarded',
                          value: '${formatQty(week.discarded)} ${product.unit}',
                          color: week.discarded > 0
                              ? AppColors.danger
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (final log in logs.take(10))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    log.discarded ? Icons.block : Icons.check_circle_outline,
                    color: log.discarded ? AppColors.danger : AppColors.success,
                  ),
                  title: Text('${formatQty(log.quantity)} ${log.product.unit}'
                      '${log.discarded ? ' · discarded' : ''}'),
                  subtitle: Text(formatDay(log.date)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () async {
                      if (await confirmAction(context,
                          title: 'Delete this entry?',
                          message: 'It will be removed from the totals.')) {
                        await FarmStore.instance.deleteProduction(log.id);
                      }
                    },
                  ),
                ),
              const SectionLabel('Health history'),
              if (history.isEmpty)
                const Text('Nothing recorded yet.',
                    style: TextStyle(color: AppColors.textSecondary)),
              for (final e in history) _HistoryTile(event: e, species: animal.species),
            ],
          ),
        );
      },
    );
  }

  Future<void> _delete(BuildContext context, Animal animal) async {
    final ok = await confirmAction(
      context,
      title: 'Delete ${animal.name}?',
      message: 'Its health history, production records and the costs '
          'recorded with them will also be deleted. This cannot be undone.',
    );
    if (!ok) return;
    await FarmStore.instance.deleteAnimal(animal.id);
    if (context.mounted) Navigator.pop(context);
  }
}

class _Header extends StatelessWidget {
  final Animal animal;

  const _Header({required this.animal});

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      animal.isFlock ? '${animal.headCount} birds' : animal.species.label,
      if (animal.birthDate != null)
        '${formatAge(animal.birthDate!)} old · ${animal.species.dateLabel.toLowerCase()} ${formatDay(animal.birthDate!)}',
      if (animal.producing) animal.species.producingLabel,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SpeciesAvatar(animal.species, radius: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(l, style: const TextStyle(fontSize: 13.5)),
                    ),
                  if (animal.notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(animal.notes,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final ScheduleStatus status;
  final DateTime now;

  const _ScheduleTile({required this.status, required this.now});

  @override
  Widget build(BuildContext context) {
    final (String text, Color color) = switch (status.state) {
      ScheduleState.overdue => ('Overdue', AppColors.danger),
      ScheduleState.dueSoon => ('Due soon', AppColors.warning),
      ScheduleState.noRecord => ('No record', AppColors.textSecondary),
      ScheduleState.upToDate => ('Up to date', AppColors.success),
      ScheduleState.completed => ('Done', AppColors.success),
    };

    final String detail;
    if (status.state == ScheduleState.completed) {
      detail = 'Given ${formatDay(status.lastGiven!)} · single dose';
    } else if (status.dueOn != null) {
      detail = 'Due ${formatDay(status.dueOn!)} (${relativeDay(status.dueOn!, from: now)})'
          '${status.lastGiven != null ? ' · last ${formatDay(status.lastGiven!)}' : ''}';
    } else {
      detail = status.spec.note;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(status.spec.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
        subtitle: Text(detail, style: const TextStyle(fontSize: 12.5)),
        trailing: Pill(text, color: color),
        onTap: status.state == ScheduleState.completed
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HealthEventFormScreen(
                      animal: status.animal,
                      spec: status.spec,
                    ),
                  ),
                ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HealthEvent event;
  final Species species;

  const _HistoryTile({required this.event, required this.species});

  @override
  Widget build(BuildContext context) {
    final w = <String>[
      if (event.withdrawalDaysFor(species.dailyProduct) > 0)
        '${species.dailyProduct.label.toLowerCase()} ${event.withdrawalDaysFor(species.dailyProduct)}d',
      if (event.meatWithdrawalDays > 0) 'meat ${event.meatWithdrawalDays}d',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(switch (event.type) {
          HealthEventType.vaccination => Icons.vaccines_outlined,
          HealthEventType.treatment => Icons.medication_outlined,
          HealthEventType.deworming => Icons.bug_report_outlined,
        }),
        title: Text(event.name),
        subtitle: Text([
          '${event.type.label} · ${formatDay(event.date)}',
          if (w.isNotEmpty) 'Withdrawal: ${w.join(', ')}',
          if (event.cost > 0) formatTaka(event.cost),
        ].join('\n')),
        isThreeLine: w.isNotEmpty || event.cost > 0,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () async {
            if (await confirmAction(context,
                title: 'Delete this record?',
                message: 'Its withdrawal period and any cost recorded with '
                    'it will be removed too.')) {
              await FarmStore.instance.deleteHealthEvent(event.id);
            }
          },
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Figure({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      );
}
