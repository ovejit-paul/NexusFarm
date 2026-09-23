import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/ids.dart';
import '../models/livestock.dart';
import '../store/farm_store.dart';
import 'widgets.dart';

/// Adds a new animal or flock, or edits an existing one.
///
/// Species cannot be changed after creation: vaccination history is
/// species-specific, and moving a record from goat to duck would leave
/// its schedule meaningless.
class AnimalFormScreen extends StatefulWidget {
  final Animal? existing;

  const AnimalFormScreen({super.key, this.existing});

  @override
  State<AnimalFormScreen> createState() => _AnimalFormScreenState();
}

class _AnimalFormScreenState extends State<AnimalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late Species _species;
  late final TextEditingController _name;
  late final TextEditingController _count;
  late final TextEditingController _notes;
  DateTime? _birth;
  late bool _producing;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _species = e?.species ?? Species.cattle;
    _name = TextEditingController(text: e?.name ?? '');
    _count = TextEditingController(text: '${e?.headCount ?? 10}');
    _notes = TextEditingController(text: e?.notes ?? '');
    _birth = e?.birthDate;
    _producing = e?.producing ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _count.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);

    final e = widget.existing;
    final animal = Animal(
      id: e?.id ?? newId(),
      species: _species,
      name: _name.text.trim(),
      headCount: _species.keptAsFlock ? int.parse(_count.text.trim()) : 1,
      birthDate: _birth,
      producing: _producing,
      notes: _notes.text.trim(),
      createdAt: e?.createdAt ?? today(),
    );

    await FarmStore.instance.saveAnimal(animal);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final flock = _species.keptAsFlock;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit ${widget.existing!.name}' : 'Add animal')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_editing) ...[
              const SectionLabel('What kind?', padding: EdgeInsets.only(bottom: 8)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in Species.values)
                    ChoiceChip(
                      avatar: Text(s.emoji),
                      label: Text(s.label),
                      selected: _species == s,
                      onSelected: (_) => setState(() => _species = s),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                flock
                    ? 'Chickens and ducks are recorded as a flock.'
                    : 'Cattle and goats are recorded one animal at a time.',
                style: const TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 18),
            ],
            TextFormField(
              controller: _name,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: flock ? 'Flock name' : 'Name or ear tag',
                hintText: flock ? 'e.g. Layer flock' : 'e.g. Lali, or BD-0421',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Give it a name' : null,
            ),
            if (flock) ...[
              const SizedBox(height: 6),
              TextFormField(
                controller: _count,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Number of birds'),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n < 1) return 'Enter at least 1';
                  if (n > 100000) return 'That seems too many — check the number';
                  return null;
                },
              ),
            ],
            const SizedBox(height: 14),
            DateField(
              label: '${_species.dateLabel} (optional)',
              value: _birth,
              onTap: () async {
                final d = await pickDay(context, _birth ?? today(),
                    last: DateTime.now());
                if (d != null) setState(() => _birth = d);
              },
              onClear: () => setState(() => _birth = null),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                'With a date, first vaccinations are scheduled by age.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _producing,
              onChanged: (v) => setState(() => _producing = v),
              title: Text('${_species.producingLabel} now'),
              subtitle: Text(flock
                  ? 'Egg records and egg withdrawal warnings'
                  : 'Milk records and milk withdrawal warnings'),
            ),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15)),
              child: Text(_editing ? 'Save changes' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }
}
