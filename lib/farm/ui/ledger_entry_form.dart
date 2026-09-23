import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/ids.dart';
import '../models/ledger.dart';
import '../store/farm_store.dart';
import 'widgets.dart';

class LedgerEntryForm extends StatefulWidget {
  final EntryKind initialKind;

  const LedgerEntryForm({super.key, this.initialKind = EntryKind.expense});

  @override
  State<LedgerEntryForm> createState() => _LedgerEntryFormState();
}

class _LedgerEntryFormState extends State<LedgerEntryForm> {
  final _formKey = GlobalKey<FormState>();
  late EntryKind _kind = widget.initialKind;
  LedgerCategory _category = LedgerCategory.general;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = today();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    await FarmStore.instance.addLedgerEntry(LedgerEntry(
      id: newId(),
      kind: _kind,
      category: _category,
      amount: double.parse(_amount.text.trim()),
      date: _date,
      note: _note.text.trim(),
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ledger entry')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<EntryKind>(
                segments: const [
                  ButtonSegment(
                      value: EntryKind.expense,
                      label: Text('Spent'),
                      icon: Icon(Icons.north_east)),
                  ButtonSegment(
                      value: EntryKind.income,
                      label: Text('Earned'),
                      icon: Icon(Icons.south_west)),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _amount,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (Tk)'),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return 'Enter an amount above zero';
                  if (n > 100000000) return 'Check this amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<LedgerCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in LedgerCategory.values)
                    DropdownMenuItem(value: c, child: Text(c.label)),
                ],
                onChanged: (v) =>
                    setState(() => _category = v ?? LedgerCategory.general),
              ),
              const SizedBox(height: 12),
              DateField(
                label: 'Date',
                value: _date,
                onTap: () async {
                  final d =
                      await pickDay(context, _date, last: DateTime.now());
                  if (d != null) setState(() => _date = d);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'What for?',
                  hintText: _kind == EntryKind.income
                      ? 'e.g. Sold 20 L milk'
                      : 'e.g. Cattle feed, 2 bags',
                ),
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
