import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/dates.dart';
import '../../core/ids.dart';
import '../data/drug_presets.dart';
import '../data/schedules.dart';
import '../models/livestock.dart';
import '../store/farm_store.dart';
import 'widgets.dart';

/// Records a vaccination, treatment or deworming.
///
/// Withdrawal fields are always shown and always editable. A preset only
/// fills them in; the farmer is asked to check the numbers against the
/// label in their hand, because that is the only figure that counts.
class HealthEventFormScreen extends StatefulWidget {
  final Animal animal;

  /// When opened from a schedule row, the vaccine is chosen already.
  final ScheduleSpec? spec;

  const HealthEventFormScreen({super.key, required this.animal, this.spec});

  @override
  State<HealthEventFormScreen> createState() => _HealthEventFormScreenState();
}

class _HealthEventFormScreenState extends State<HealthEventFormScreen> {
  static const _other = '__other__';

  final _formKey = GlobalKey<FormState>();
  late HealthEventType _type;
  String? _vaccine;
  DrugPreset? _preset;
  final _name = TextEditingController();
  final _dailyDays = TextEditingController(text: '0');
  final _meatDays = TextEditingController(text: '0');
  final _cost = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = today();
  bool _saving = false;

  Species get _species => widget.animal.species;
  Product get _daily => _species.dailyProduct;

  List<ScheduleSpec> get _vaccines => schedulesFor(_species)
      .where((s) => s.type == HealthEventType.vaccination)
      .toList();

  @override
  void initState() {
    super.initState();
    final spec = widget.spec;
    _type = spec?.type ?? HealthEventType.vaccination;
    if (spec != null) {
      if (spec.type == HealthEventType.vaccination) {
        _vaccine = spec.name;
      } else {
        _name.text = '';
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _dailyDays, _meatDays, _cost, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyPreset(DrugPreset? p) {
    setState(() {
      _preset = p;
      if (p == null) return;
      _name.text = p.name;
      _dailyDays.text =
          '${_daily == Product.milk ? p.milkDays : p.eggDays}';
      _meatDays.text = '${p.meatDays}';
    });
  }

  String get _resolvedName {
    if (_type == HealthEventType.vaccination && _vaccine != null &&
        _vaccine != _other) {
      return _vaccine!;
    }
    return _name.text.trim();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    if (_resolvedName.isEmpty) return;
    setState(() => _saving = true);

    final daily = int.parse(_dailyDays.text.trim());
    final meat = int.parse(_meatDays.text.trim());
    final cost = double.tryParse(_cost.text.trim()) ?? 0;

    final event = HealthEvent(
      id: newId(),
      animalId: widget.animal.id,
      type: _type,
      name: _resolvedName,
      date: _date,
      milkWithdrawalDays: _daily == Product.milk ? daily : 0,
      eggWithdrawalDays: _daily == Product.eggs ? daily : 0,
      meatWithdrawalDays: meat,
      cost: cost,
      notes: _notes.text.trim(),
    );

    await FarmStore.instance.addHealthEvent(event);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    if (daily > 0 || meat > 0) {
      final longest = daily > meat ? daily : meat;
      messenger.showSnackBar(SnackBar(
        content: Text('Saved. Withdrawal period runs until '
            '${formatDay(addDays(_date, longest))}.'),
      ));
    }
  }

  String? _daysValidator(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    if (n == null || n < 0) return 'Enter 0 or more';
    if (n > 365) return 'Check this — over a year';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.animal;
    final showNameField = _type != HealthEventType.vaccination ||
        _vaccine == _other ||
        _vaccines.isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text('Health record · ${a.name}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<HealthEventType>(
              segments: const [
                ButtonSegment(
                    value: HealthEventType.vaccination,
                    label: Text('Vaccine'),
                    icon: Icon(Icons.vaccines_outlined)),
                ButtonSegment(
                    value: HealthEventType.treatment,
                    label: Text('Treatment'),
                    icon: Icon(Icons.medication_outlined)),
                ButtonSegment(
                    value: HealthEventType.deworming,
                    label: Text('Deworm'),
                    icon: Icon(Icons.bug_report_outlined)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _preset = null;
              }),
            ),
            const SizedBox(height: 18),

            if (_type == HealthEventType.vaccination && _vaccines.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _vaccine,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Vaccine'),
                items: [
                  for (final v in _vaccines)
                    DropdownMenuItem(value: v.name, child: Text(v.name)),
                  const DropdownMenuItem(value: _other, child: Text('Other…')),
                ],
                onChanged: (v) => setState(() => _vaccine = v),
                validator: (v) => v == null ? 'Choose a vaccine' : null,
              ),

            if (_type != HealthEventType.vaccination) ...[
              DropdownButtonFormField<DrugPreset?>(
                // Keyed on the record type: switching type clears the
                // preset, and the field must rebuild to show that.
                key: ValueKey(_type),
                initialValue: _preset,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Common medicine (optional)'),
                items: [
                  const DropdownMenuItem<DrugPreset?>(
                      value: null, child: Text('None — enter below')),
                  for (final p in drugPresets)
                    DropdownMenuItem<DrugPreset?>(
                        value: p, child: Text(p.name)),
                ],
                onChanged: _applyPreset,
              ),
              const SizedBox(height: 12),
            ],

            if (showNameField) ...[
              if (_type == HealthEventType.vaccination)
                const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: switch (_type) {
                    HealthEventType.vaccination => 'Vaccine name',
                    HealthEventType.treatment => 'Medicine or treatment',
                    HealthEventType.deworming => 'Dewormer used',
                  },
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
            ],

            const SizedBox(height: 14),
            DateField(
              label: 'Date given',
              value: _date,
              onTap: () async {
                final d = await pickDay(context, _date, last: DateTime.now());
                if (d != null) setState(() => _date = d);
              },
            ),

            const SectionLabel('Withdrawal period — from the label'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dailyDays,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: '${_daily.label} (days)',
                    ),
                    validator: _daysValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _meatDays,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Meat (days)'),
                    validator: _daysValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            NoticeBox(
              icon: Icons.warning_amber_rounded,
              color: AppColors.warning,
              title: 'Check the label',
              body: [
                if (_preset != null && _preset!.warning.isNotEmpty)
                  _preset!.warning,
                'Withdrawal periods differ between brands. Use the number '
                    'printed on your product. Most vaccines have none — '
                    'leave them at 0 unless the label says otherwise.',
              ].join('\n\n'),
            ),

            TextFormField(
              controller: _cost,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cost in Tk (optional)',
                helperText: 'Added to the farm ledger as an expense',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = double.tryParse(v.trim());
                return (n == null || n < 0) ? 'Enter an amount' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15)),
              child: const Text('Save record'),
            ),
          ],
        ),
      ),
    );
  }
}
