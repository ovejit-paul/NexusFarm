/// Common veterinary products with typical withdrawal periods.
///
/// ============================================================
/// THESE ARE STARTING POINTS, NOT ANSWERS.
///
/// Withdrawal periods differ between brands of the same drug, and
/// between injectable and oral forms. The number printed on the
/// product in the farmer's hand is the only one that counts, and the
/// form shows these values in editable fields for exactly that reason.
///
/// Values here lean long rather than short: a day too cautious costs a
/// litre of milk; a day too short puts residue in someone's food.
/// ============================================================
class DrugPreset {
  final String name;
  final int milkDays;
  final int eggDays;
  final int meatDays;

  /// Shown under the fields. Some products must never be used in
  /// milking or laying animals at all, and this is where that is said.
  final String warning;

  const DrugPreset({
    required this.name,
    required this.milkDays,
    required this.eggDays,
    required this.meatDays,
    this.warning = '',
  });
}

const drugPresets = <DrugPreset>[
  DrugPreset(
    name: 'Oxytetracycline (injection)',
    milkDays: 7,
    eggDays: 7,
    meatDays: 28,
    warning: 'Long-acting forms often need longer. Check the label.',
  ),
  DrugPreset(
    name: 'Penicillin-streptomycin (injection)',
    milkDays: 4,
    eggDays: 0,
    meatDays: 30,
  ),
  DrugPreset(
    name: 'Albendazole (dewormer)',
    milkDays: 3,
    eggDays: 7,
    meatDays: 27,
    warning: 'Many labels forbid use in the first months of pregnancy.',
  ),
  DrugPreset(
    name: 'Ivermectin (injection)',
    milkDays: 28,
    eggDays: 0,
    meatDays: 35,
    warning: 'Most ivermectin products must not be used in milking '
        'animals at all. Read the label before use.',
  ),
  DrugPreset(
    name: 'Enrofloxacin (poultry, in water)',
    milkDays: 0,
    eggDays: 10,
    meatDays: 10,
    warning: 'Many labels forbid use in laying hens.',
  ),
  DrugPreset(
    name: 'Tylosin (poultry, in water)',
    milkDays: 0,
    eggDays: 3,
    meatDays: 5,
  ),
  DrugPreset(
    name: 'Sulfadimidine',
    milkDays: 5,
    eggDays: 10,
    meatDays: 15,
  ),
];
