/// How much of each nutrient a crop needs, kg per hectare.
///
/// Bangladesh convention: P and K given as the element, not as oxide
/// (P2O5 / K2O). Mixing those up is the commonest error in fertilizer
/// maths — the oxide figure for P is about 2.3x the elemental one, so
/// the mistake means over-applying by more than double.
class NutrientNeed {
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double sulphur;

  const NutrientNeed({
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    this.sulphur = 0,
  });

  NutrientNeed scaled(double factor) => NutrientNeed(
        nitrogen: nitrogen * factor,
        phosphorus: phosphorus * factor,
        potassium: potassium * factor,
        sulphur: sulphur * factor,
      );
}

/// One instalment of a split nitrogen dose.
class NitrogenSplit {
  final String when;
  final double share; // 0.0 - 1.0

  const NitrogenSplit(this.when, this.share);
}

/// A crop the calculator knows about.
class FertilizerCrop {
  final String name;
  final String category;

  /// Requirement at medium soil fertility, kg per hectare.
  final NutrientNeed need;

  /// How the nitrogen dose is spread across the season. Phosphorus,
  /// potassium and sulphur normally go in fully at land preparation,
  /// so only nitrogen needs a schedule.
  final List<NitrogenSplit> nitrogenSplits;

  /// Anything the numbers alone do not tell the farmer.
  final String note;

  const FertilizerCrop({
    required this.name,
    required this.category,
    required this.need,
    required this.nitrogenSplits,
    this.note = '',
  });
}

/// Soil fertility class. Without a soil test this is a judgement, so
/// the adjustment is deliberately coarse.
enum SoilFertility { low, medium, high }

extension SoilFertilityInfo on SoilFertility {
  String get label => switch (this) {
        SoilFertility.low => 'Low',
        SoilFertility.medium => 'Medium',
        SoilFertility.high => 'High',
      };

  String get hint => switch (this) {
        SoilFertility.low => 'Pale soil, poor yields, little organic matter',
        SoilFertility.medium => 'Average yields — pick this if unsure',
        SoilFertility.high => 'Dark soil, good yields, regular manure',
      };

  double get factor => switch (this) {
        SoilFertility.low => 1.20,
        SoilFertility.medium => 1.00,
        SoilFertility.high => 0.80,
      };
}

/// Soil texture. Does not change how much to apply, but does change
/// how to apply it — sandy soil loses nitrogen quickly.
enum SoilType { sandy, loam, clay }

extension SoilTypeInfo on SoilType {
  String get label => switch (this) {
        SoilType.sandy => 'Sandy',
        SoilType.loam => 'Loam',
        SoilType.clay => 'Clay',
      };

  String get hint => switch (this) {
        SoilType.sandy => 'Gritty, water drains fast',
        SoilType.loam => 'Crumbly, holds water but drains',
        SoilType.clay => 'Sticky when wet, cracks when dry',
      };

  String get advice => switch (this) {
        SoilType.sandy =>
          'Sandy soil loses nitrogen with the water. Split the urea into '
              'more instalments and never apply it all at once.',
        SoilType.loam =>
          'Loam holds nutrients well. The standard schedule works as it is.',
        SoilType.clay =>
          'Clay holds nutrients but drains poorly. Apply when the field is '
              'not waterlogged, or the fertilizer will not reach the roots.',
      };
}

/// Land units farmers actually use. Recommendations are per hectare,
/// so everything converts to that.
enum LandUnit { bigha, decimal, acre, hectare, katha }

extension LandUnitInfo on LandUnit {
  String get label => switch (this) {
        LandUnit.bigha => 'Bigha',
        LandUnit.decimal => 'Decimal (shotok)',
        LandUnit.acre => 'Acre',
        LandUnit.hectare => 'Hectare',
        LandUnit.katha => 'Katha',
      };

  /// Hectares in one of this unit.
  ///
  /// Bigha is not standard across Bangladesh — 33 decimal is the most
  /// common definition and the one used here. The interface says so
  /// rather than pretending the number is exact everywhere.
  double get inHectares => switch (this) {
        LandUnit.bigha => 0.1338,
        LandUnit.decimal => 0.004047,
        LandUnit.acre => 0.4047,
        LandUnit.hectare => 1.0,
        LandUnit.katha => 0.00669,
      };
}

/// A fertilizer product and what share of a nutrient it carries.
class FertilizerProduct {
  final String name;
  final String localName;
  final double nutrientFraction;
  final String supplies;

  const FertilizerProduct({
    required this.name,
    required this.localName,
    required this.nutrientFraction,
    required this.supplies,
  });
}

/// The four products stocked by almost every input shop in Bangladesh.
class Fertilizers {
  static const urea = FertilizerProduct(
    name: 'Urea',
    localName: 'ইউরিয়া',
    nutrientFraction: 0.46,
    supplies: 'Nitrogen',
  );
  static const tsp = FertilizerProduct(
    name: 'TSP',
    localName: 'টিএসপি',
    nutrientFraction: 0.20,
    supplies: 'Phosphorus',
  );
  static const mop = FertilizerProduct(
    name: 'MoP',
    localName: 'এমওপি',
    nutrientFraction: 0.50,
    supplies: 'Potassium',
  );
  static const gypsum = FertilizerProduct(
    name: 'Gypsum',
    localName: 'জিপসাম',
    nutrientFraction: 0.18,
    supplies: 'Sulphur',
  );
}

class DoseInstalment {
  final String when;
  final double kg;

  const DoseInstalment(this.when, this.kg);
}

/// One line of the answer: how much of one product to buy.
class FertilizerDose {
  final FertilizerProduct product;
  final double totalKg;
  final List<DoseInstalment> instalments;

  const FertilizerDose({
    required this.product,
    required this.totalKg,
    required this.instalments,
  });
}

/// Everything the calculator returns.
class FertilizerPlan {
  final FertilizerCrop crop;
  final String areaLabel;
  final List<FertilizerDose> doses;
  final String soilAdvice;
  final String cropNote;

  const FertilizerPlan({
    required this.crop,
    required this.areaLabel,
    required this.doses,
    required this.soilAdvice,
    required this.cropNote,
  });
}
