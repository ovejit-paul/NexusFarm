import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/fertilizer_models.dart';
import '../services/fertilizer_calculator.dart';
import '../services/fertilizer_data.dart';

/// Asks four questions — crop, field size, soil fertility, soil type —
/// and answers in products, not nutrients. "120 kg nitrogen" means
/// nothing at an input shop; "260 kg urea" is something a farmer can
/// act on.
class FertilizerScreen extends StatefulWidget {
  const FertilizerScreen({super.key});

  @override
  State<FertilizerScreen> createState() => _FertilizerScreenState();
}

class _FertilizerScreenState extends State<FertilizerScreen> {
  FertilizerCrop? _crop;
  final _areaController = TextEditingController();
  LandUnit _unit = LandUnit.bigha;
  SoilFertility _fertility = SoilFertility.medium;
  SoilType _soilType = SoilType.loam;

  FertilizerPlan? _plan;
  String? _error;

  @override
  void dispose() {
    _areaController.dispose();
    super.dispose();
  }

  void _calculate() {
    final crop = _crop;
    if (crop == null) {
      setState(() => _error = 'Please choose a crop first');
      return;
    }

    final area = double.tryParse(_areaController.text.trim());
    if (area == null || area <= 0) {
      setState(() => _error = 'Please enter your field size');
      return;
    }

    setState(() {
      _error = null;
      _plan = FertilizerCalculator.calculate(
        crop: crop,
        areaValue: area,
        unit: _unit,
        fertility: _fertility,
        soilType: _soilType,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fertilizer'),
        actions: [
          if (_plan != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Change answers',
              onPressed: () => setState(() => _plan = null),
            ),
        ],
      ),
      body: _plan == null ? _buildForm() : _buildResult(_plan!),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _label('Which crop?'),
        const SizedBox(height: 8),
        DropdownButtonFormField<FertilizerCrop>(
          initialValue: _crop,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.grass),
            hintText: 'Choose a crop',
          ),
          items: [
            for (final crop in fertilizerCrops)
              DropdownMenuItem(
                value: crop,
                child: Text('${crop.name}  ·  ${crop.category}'),
              ),
          ],
          onChanged: (value) => setState(() => _crop = value),
        ),
        const SizedBox(height: 22),

        _label('How big is the field?'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _areaController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'e.g. 2'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<LandUnit>(
                initialValue: _unit,
                isExpanded: true,
                items: [
                  for (final u in LandUnit.values)
                    DropdownMenuItem(value: u, child: Text(u.label)),
                ],
                onChanged: (v) =>
                    setState(() => _unit = v ?? LandUnit.bigha),
              ),
            ),
          ],
        ),
        if (_unit == LandUnit.bigha)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Using 1 bigha = 33 decimal. A bigha is a different size in '
              'some districts — check what is used locally.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        const SizedBox(height: 22),

        _label('How fertile is the soil?'),
        RadioGroup<SoilFertility>(
          groupValue: _fertility,
          onChanged: (v) =>
              setState(() => _fertility = v ?? SoilFertility.medium),
          child: Column(
            children: [
              for (final f in SoilFertility.values)
                RadioListTile<SoilFertility>(
                  value: f,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(f.label),
                  subtitle: Text(f.hint, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        _label('What is the soil like?'),
        RadioGroup<SoilType>(
          groupValue: _soilType,
          onChanged: (v) => setState(() => _soilType = v ?? SoilType.loam),
          child: Column(
            children: [
              for (final s in SoilType.values)
                RadioListTile<SoilType>(
                  value: s,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(s.label),
                  subtitle: Text(s.hint, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13)),
        ],

        const SizedBox(height: 22),
        ElevatedButton(
          onPressed: _calculate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Calculate',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildResult(FertilizerPlan plan) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plan.crop.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                '${plan.areaLabel}  ·  ${_fertility.label} fertility  ·  ${_soilType.label} soil',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        _label('What to buy'),
        const SizedBox(height: 10),
        for (final dose in plan.doses) _shoppingRow(dose),

        const SizedBox(height: 24),
        _label('When to apply'),
        const SizedBox(height: 10),
        for (final dose in plan.doses)
          if (dose.instalments.length > 1) _schedule(dose),
        _basalNote(plan),

        if (plan.cropNote.isNotEmpty) ...[
          const SizedBox(height: 20),
          _noteBox(Icons.lightbulb_outline, AppColors.primaryDark,
              'About ${plan.crop.name.toLowerCase()}', plan.cropNote),
        ],
        const SizedBox(height: 12),
        _noteBox(Icons.landscape_outlined, AppColors.primaryDark,
            '${_soilType.label} soil', plan.soilAdvice),
        const SizedBox(height: 12),
        _noteBox(
          Icons.info_outline,
          AppColors.warning,
          'This is an estimate',
          'These amounts assume average conditions for your soil fertility '
              'level. A soil test from your upazila agriculture office gives '
              'a more accurate figure, and applying more than recommended '
              'wastes money and harms the soil.',
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _shoppingRow(FertilizerDose dose) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${dose.product.name}  (${dose.product.localName})',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('Supplies ${dose.product.supplies.toLowerCase()}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Text(
              FertilizerCalculator.formatKg(dose.totalKg),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _schedule(FertilizerDose dose) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${dose.product.name} — split into ${dose.instalments.length}',
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          for (var i = 0; i < dose.instalments.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text('${i + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        )),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(dose.instalments[i].when,
                        style: const TextStyle(fontSize: 14, height: 1.35)),
                  ),
                  const SizedBox(width: 8),
                  Text(FertilizerCalculator.formatKg(dose.instalments[i].kg),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _basalNote(FertilizerPlan plan) {
    final basal = plan.doses
        .where((d) => d.instalments.length == 1)
        .map((d) => d.product.name)
        .toList();
    if (basal.isEmpty) return const SizedBox.shrink();

    return Text(
      '${basal.join(', ')} — all of it goes in at final land preparation. '
      'Unlike nitrogen these do not wash away, so there is no reason to split them.',
      style: const TextStyle(
          fontSize: 13, color: AppColors.textSecondary, height: 1.4),
    );
  }

  Widget _noteBox(IconData icon, Color color, String title, String body) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: color)),
                const SizedBox(height: 3),
                Text(body,
                    style: const TextStyle(fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppColors.primaryDark,
        ),
      );
}
