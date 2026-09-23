import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/dates.dart';
import '../logic/livestock_logic.dart';
import '../models/livestock.dart';
import '../store/farm_store.dart';
import 'animal_detail_screen.dart';
import 'animal_form_screen.dart';
import 'widgets.dart';

class LivestockScreen extends StatelessWidget {
  const LivestockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = FarmStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final animals = store.data.animals;
        return Scaffold(
          appBar: AppBar(title: const Text('Livestock')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnimalFormScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
          body: animals.isEmpty
              ? const EmptyState(
                  icon: Icons.pets_outlined,
                  title: 'No animals yet',
                  message: 'Add your cattle and goats one by one, and your '
                      'chickens and ducks as flocks. Vaccination dates and '
                      'withdrawal periods will then be tracked for you.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  children: [
                    for (final species in Species.values)
                      ..._group(context, species,
                          animals.where((a) => a.species == species).toList()),
                  ],
                ),
        );
      },
    );
  }

  List<Widget> _group(
      BuildContext context, Species species, List<Animal> list) {
    if (list.isEmpty) return const [];
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final heads = list.fold<int>(0, (sum, a) => sum + a.headCount);
    return [
      SectionLabel('${species.emoji}  ${species.label} · $heads'),
      for (final a in list) _AnimalCard(animal: a),
    ];
  }
}

class _AnimalCard extends StatelessWidget {
  final Animal animal;

  const _AnimalCard({required this.animal});

  @override
  Widget build(BuildContext context) {
    final data = FarmStore.instance.data;
    final now = today();
    final holds = withdrawalsFor(animal, data.healthEvents, now);
    final overdue = scheduleFor(animal, data.healthEvents, now)
        .where((s) => s.state == ScheduleState.overdue)
        .length;

    final parts = <String>[
      if (animal.isFlock) '${animal.headCount} birds',
      if (animal.birthDate != null) formatAge(animal.birthDate!),
      if (animal.producing) animal.species.producingLabel,
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: SpeciesAvatar(animal.species),
        title: Text(animal.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: parts.isEmpty ? null : Text(parts.join(' · ')),
        trailing: holds.isNotEmpty
            ? const Pill('On hold', color: AppColors.danger)
            : overdue > 0
                ? Pill('$overdue overdue', color: AppColors.warning)
                : const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AnimalDetailScreen(animalId: animal.id)),
        ),
      ),
    );
  }
}
