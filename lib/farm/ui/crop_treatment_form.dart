import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dates.dart';
import '../../core/ids.dart';
import '../models/crop_treatment.dart';
import '../store/farm_store.dart';
import 'widgets.dart';

/// Records a spray and tracks when the crop becomes safe to harvest.
///
/// Can be opened from a diagnosis, in which case crop and pre-harvest
/// interval come pre-filled from the result.
class CropTreatmentForm extends StatefulWidget {
  final String initialCrop;
  final int? initialPhiDays;
  final String initialNotes;

  const CropTreatmentForm({
    super.key,
    this.initialCrop = '',
    this.initialPhiDays,
    this.initialNotes = '',
  });

  @override
  State<CropTreatmentForm> createState() => _CropTreatmentFormState();
}

class _CropTreatmentFormState extends State<CropTreatmentForm> {
  final _formKey = GlobalKey<FormState>();
  late final _crop = TextEditingController(text: widget.initialCrop);
  final _plot = TextEditingController();
  final _product = TextEditingController();
  late final _phi =
      TextEditingController(text: widget.initialPhiDays?.toString() ?? '');
  final _cost = TextEditingController();
  late final _notes = TextEditingController(text: widget.initialNotes);
  DateTime _date = today();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_crop, _plot, _product, _phi, _cost, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final t = CropTreatment(
      id: newId(),
      crop: _crop.text.trim(),
      plot: _plot.text.trim(),
      product: _product.text.trim(),
      date: _date,
      phiDays: int.parse(_phi.text.trim()),
      cost: double.tryParse(_cost.text.trim()) ?? 0,
      notes: _notes.text.trim(),
    );
    await FarmStore.instance.addCropTreatment(t);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text(t.phiDays > 0
          ? 'Saved. Safe to harvest from ${formatDay(t.safeHarvestFrom)}.'
          : 'Saved.'),
    ));
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Record a spray')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _crop,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Crop'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _plot,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Field or plot (optional)',
                  hintText: 'e.g. North field',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _product,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Product sprayed',
                  hintText: 'e.g. Mancozeb',
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              DateField(
                label: 'Date sprayed',
                value: _date,
                onTap: () async {
                  final d =
                      await pickDay(context, _date, last: DateTime.now());
                  if (d != null) setState(() => _date = d);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phi,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Pre-harvest interval (days)',
                  helperText: 'From the product label',
                ),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n < 0) return 'Enter 0 or more';
                  if (n > 365) return 'Check this — over a year';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cost,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Cost in Tk (optional)',
                  helperText: 'Added to the farm ledger',
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
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
}
