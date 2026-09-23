import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/dates.dart';
import '../../core/format.dart';
import '../store/farm_store.dart';
import 'crop_treatment_form.dart';
import 'widgets.dart';

class CropLogScreen extends StatelessWidget {
  const CropLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = FarmStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = today();
        final list = [...store.data.cropTreatments]
          ..sort((a, b) => b.date.compareTo(a.date));
        return Scaffold(
          appBar: AppBar(title: const Text('Spray records')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CropTreatmentForm()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Record spray'),
          ),
          body: list.isEmpty
              ? const EmptyState(
                  icon: Icons.sanitizer_outlined,
                  title: 'No sprays recorded',
                  message: 'Record each spray and NexusFarm will tell you '
                      'when the crop is safe to harvest.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    for (final t in list)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(t.displayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text([
                            '${t.product} · ${formatDay(t.date)}',
                            if (t.phiDays > 0)
                              'Safe from ${formatDay(t.safeHarvestFrom)}',
                            if (t.cost > 0) formatTaka(t.cost),
                          ].join('\n')),
                          isThreeLine: t.phiDays > 0 || t.cost > 0,
                          trailing: t.isHoldActive(now)
                              ? Pill(
                                  '${daysBetween(now, t.safeHarvestFrom)}d hold',
                                  color: AppColors.danger)
                              : const Pill('Safe', color: AppColors.success),
                          onLongPress: () async {
                            if (await confirmAction(context,
                                title: 'Delete this record?',
                                message: 'Its harvest hold and cost will be '
                                    'removed too.')) {
                              await store.deleteCropTreatment(t.id);
                            }
                          },
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
