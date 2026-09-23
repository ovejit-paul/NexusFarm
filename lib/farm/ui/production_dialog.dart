import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/dates.dart';
import '../logic/livestock_logic.dart';
import '../models/livestock.dart';
import '../store/farm_store.dart';
import 'widgets.dart';

Future<void> showProductionDialog(BuildContext context, Animal animal) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ProductionDialog(animal: animal),
    );

/// Its own widget so it owns and disposes its text controller — disposing
/// a controller right after `showDialog` returns can crash the closing
/// animation, which still reads it.
class _ProductionDialog extends StatefulWidget {
  final Animal animal;

  const _ProductionDialog({required this.animal});

  @override
  State<_ProductionDialog> createState() => _ProductionDialogState();
}

class _ProductionDialogState extends State<_ProductionDialog> {
  final _qty = TextEditingController();
  DateTime _date = today();
  String? _error;
  bool _saving = false;

  Product get _product => widget.animal.species.dailyProduct;

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final q = double.tryParse(_qty.text.trim());
    if (q == null || q <= 0) {
      setState(() => _error = 'Enter an amount above zero');
      return;
    }
    if (_product == Product.eggs && q != q.roundToDouble()) {
      setState(() => _error = 'Whole eggs only');
      return;
    }
    setState(() => _saving = true);
    await FarmStore.instance
        .addProduction(animal: widget.animal, date: _date, quantity: q);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hold = holdOn(widget.animal, _product,
        FarmStore.instance.data.healthEvents, _date);

    return AlertDialog(
      title: Text('${_product.label} · ${widget.animal.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _qty,
              autofocus: true,
              keyboardType: _product == Product.eggs
                  ? TextInputType.number
                  : const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText:
                    _product == Product.milk ? 'Litres' : 'Eggs collected',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            DateField(
              label: 'Date',
              value: _date,
              onTap: () async {
                final d = await pickDay(context, _date, last: DateTime.now());
                if (d != null) setState(() => _date = d);
              },
            ),
            if (hold != null) ...[
              const SizedBox(height: 12),
              NoticeBox(
                icon: Icons.block,
                color: AppColors.danger,
                title: 'Under withdrawal until ${formatDay(hold.safeFrom)}',
                body: 'This will be recorded as discarded. Do not sell it, '
                    'and do not ${_product == Product.milk ? 'drink' : 'eat'} it.',
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(hold != null ? 'Record as discarded' : 'Save'),
        ),
      ],
    );
  }
}
