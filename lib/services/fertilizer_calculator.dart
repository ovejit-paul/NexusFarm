import '../models/fertilizer_models.dart';

/// Turns a crop, a field size and two soil answers into a shopping
/// list and an application schedule.
///
/// Four steps:
///   1. Convert the field size to hectares (recommendations are per ha)
///   2. Adjust the per-hectare need for soil fertility
///   3. Scale by the field size
///   4. Convert each nutrient into kilograms of an actual product
class FertilizerCalculator {
  static FertilizerPlan calculate({
    required FertilizerCrop crop,
    required double areaValue,
    required LandUnit unit,
    required SoilFertility fertility,
    required SoilType soilType,
  }) {
    final hectares = areaValue * unit.inHectares;
    final total = crop.need.scaled(fertility.factor).scaled(hectares);

    final doses = <FertilizerDose>[];

    if (total.nitrogen > 0) {
      doses.add(_splitDose(
        product: Fertilizers.urea,
        nutrientKg: total.nitrogen,
        splits: _splitsFor(crop, soilType),
      ));
    }

    // Phosphorus, potassium and sulphur are not mobile in soil the way
    // nitrogen is, so the whole amount goes in at land preparation.
    if (total.phosphorus > 0) {
      doses.add(_singleDose(Fertilizers.tsp, total.phosphorus));
    }
    if (total.potassium > 0) {
      doses.add(_singleDose(Fertilizers.mop, total.potassium));
    }
    if (total.sulphur > 0) {
      doses.add(_singleDose(Fertilizers.gypsum, total.sulphur));
    }

    return FertilizerPlan(
      crop: crop,
      areaLabel: '${_tidy(areaValue)} ${unit.label}',
      doses: doses,
      soilAdvice: soilType.advice,
      cropNote: crop.note,
    );
  }

  /// kg of product = kg of nutrient / the nutrient fraction of that
  /// product. Urea is 46% nitrogen, so 46 kg of N needs 100 kg of urea.
  static double _productKg(FertilizerProduct product, double nutrientKg) =>
      nutrientKg / product.nutrientFraction;

  static FertilizerDose _singleDose(
      FertilizerProduct product, double nutrientKg) {
    final kg = _productKg(product, nutrientKg);
    return FertilizerDose(
      product: product,
      totalKg: kg,
      instalments: [DoseInstalment('All at final land preparation', kg)],
    );
  }

  static FertilizerDose _splitDose({
    required FertilizerProduct product,
    required double nutrientKg,
    required List<NitrogenSplit> splits,
  }) {
    final totalKg = _productKg(product, nutrientKg);
    return FertilizerDose(
      product: product,
      totalKg: totalKg,
      instalments: splits
          .map((s) => DoseInstalment(s.when, totalKg * s.share))
          .toList(),
    );
  }

  /// On sandy soil, break the last instalment in two so nitrogen
  /// arrives in smaller amounts and less washes away before the roots
  /// reach it.
  static List<NitrogenSplit> _splitsFor(FertilizerCrop crop, SoilType soil) {
    if (soil != SoilType.sandy || crop.nitrogenSplits.length < 2) {
      return crop.nitrogenSplits;
    }

    final splits = List<NitrogenSplit>.from(crop.nitrogenSplits);
    final last = splits.removeLast();
    final half = last.share / 2;

    splits.add(NitrogenSplit(last.when, half));
    splits.add(
        NitrogenSplit('${last.when} — second half, 10 days later', half));
    return splits;
  }

  static String _tidy(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  /// Rounds to something a farmer can actually measure out. Nobody
  /// buys 12.847 kg of urea.
  static String formatKg(double kg) {
    if (kg < 1) return '${(kg * 1000).round()} g';
    if (kg < 10) return '${kg.toStringAsFixed(1)} kg';
    return '${kg.round()} kg';
  }
}
