import '../models/livestock.dart';

/// A recurring vaccination or deworming for one species.
class ScheduleSpec {
  final Species species;
  final HealthEventType type;
  final String name;

  /// Days between doses. 0 means a single lifetime dose.
  final int intervalDays;

  /// Age at the first dose, used when the date of birth or hatch is known.
  final int? firstAtAgeDays;

  final String note;

  const ScheduleSpec({
    required this.species,
    required this.type,
    required this.name,
    required this.intervalDays,
    this.firstAtAgeDays,
    this.note = '',
  });

  bool get oneOff => intervalDays == 0;

  /// Vaccinations match by name, so recording "FMD" never satisfies the
  /// anthrax schedule. Deworming matches by type alone, because farmers
  /// use whichever dewormer the shop has, and any of them resets the clock.
  bool matches(HealthEvent e) => type == HealthEventType.deworming
      ? e.type == HealthEventType.deworming
      : e.type == type && e.name == name;
}

// ============================================================
// VERIFY BEFORE RELYING ON THESE.
//
// Typical intervals drawn from Department of Livestock Services
// guidance and common veterinary practice in Bangladesh. Local
// programmes and vaccine brands differ. Have the upazila livestock
// officer or a veterinarian confirm this table for your area.
// ============================================================
const schedules = <ScheduleSpec>[
  // ---------- Cattle ----------
  ScheduleSpec(
    species: Species.cattle,
    type: HealthEventType.vaccination,
    name: 'FMD (foot-and-mouth)',
    intervalDays: 180,
    firstAtAgeDays: 120,
    note: 'Every 6 months.',
  ),
  ScheduleSpec(
    species: Species.cattle,
    type: HealthEventType.vaccination,
    name: 'Anthrax',
    intervalDays: 365,
    firstAtAgeDays: 180,
    note: 'Once a year.',
  ),
  ScheduleSpec(
    species: Species.cattle,
    type: HealthEventType.vaccination,
    name: 'Black Quarter (BQ)',
    intervalDays: 365,
    firstAtAgeDays: 180,
    note: 'Once a year. Young cattle are most at risk.',
  ),
  ScheduleSpec(
    species: Species.cattle,
    type: HealthEventType.vaccination,
    name: 'HS (haemorrhagic septicaemia)',
    intervalDays: 180,
    firstAtAgeDays: 180,
    note: 'Every 6 months, ideally before the rains.',
  ),
  ScheduleSpec(
    species: Species.cattle,
    type: HealthEventType.vaccination,
    name: 'Lumpy skin disease',
    intervalDays: 365,
    firstAtAgeDays: 120,
    note: 'Once a year.',
  ),
  ScheduleSpec(
    species: Species.cattle,
    type: HealthEventType.deworming,
    name: 'Deworming',
    intervalDays: 120,
    firstAtAgeDays: 60,
    note: 'Every 3 to 4 months.',
  ),

  // ---------- Goats ----------
  ScheduleSpec(
    species: Species.goat,
    type: HealthEventType.vaccination,
    name: 'PPR (goat plague)',
    intervalDays: 365,
    firstAtAgeDays: 120,
    note: 'Yearly. Some programmes use a 3-year interval — ask your officer.',
  ),
  ScheduleSpec(
    species: Species.goat,
    type: HealthEventType.vaccination,
    name: 'Goat pox',
    intervalDays: 365,
    firstAtAgeDays: 120,
    note: 'Once a year.',
  ),
  ScheduleSpec(
    species: Species.goat,
    type: HealthEventType.vaccination,
    name: 'FMD (foot-and-mouth)',
    intervalDays: 180,
    firstAtAgeDays: 120,
    note: 'Every 6 months.',
  ),
  ScheduleSpec(
    species: Species.goat,
    type: HealthEventType.deworming,
    name: 'Deworming',
    intervalDays: 90,
    firstAtAgeDays: 60,
    note: 'Every 3 months.',
  ),

  // ---------- Chickens ----------
  ScheduleSpec(
    species: Species.chicken,
    type: HealthEventType.vaccination,
    name: 'Newcastle / Ranikhet',
    intervalDays: 60,
    firstAtAgeDays: 7,
    note: 'First dose in the first week, then every 2 months.',
  ),
  ScheduleSpec(
    species: Species.chicken,
    type: HealthEventType.vaccination,
    name: 'Gumboro (IBD)',
    intervalDays: 0,
    firstAtAgeDays: 14,
    note: 'Given once, around two weeks old.',
  ),
  ScheduleSpec(
    species: Species.chicken,
    type: HealthEventType.vaccination,
    name: 'Fowl pox',
    intervalDays: 365,
    firstAtAgeDays: 42,
    note: 'Around six weeks, then yearly for laying birds.',
  ),
  ScheduleSpec(
    species: Species.chicken,
    type: HealthEventType.vaccination,
    name: 'Fowl cholera',
    intervalDays: 180,
    firstAtAgeDays: 60,
    note: 'Every 6 months.',
  ),
  ScheduleSpec(
    species: Species.chicken,
    type: HealthEventType.deworming,
    name: 'Deworming',
    intervalDays: 90,
    firstAtAgeDays: 42,
    note: 'Every 3 months.',
  ),

  // ---------- Ducks ----------
  ScheduleSpec(
    species: Species.duck,
    type: HealthEventType.vaccination,
    name: 'Duck plague',
    intervalDays: 180,
    firstAtAgeDays: 21,
    note: 'First at three weeks, then every 6 months.',
  ),
  ScheduleSpec(
    species: Species.duck,
    type: HealthEventType.vaccination,
    name: 'Duck cholera',
    intervalDays: 180,
    firstAtAgeDays: 45,
    note: 'Every 6 months.',
  ),
  ScheduleSpec(
    species: Species.duck,
    type: HealthEventType.deworming,
    name: 'Deworming',
    intervalDays: 90,
    firstAtAgeDays: 42,
    note: 'Every 3 months.',
  ),
];

List<ScheduleSpec> schedulesFor(Species s) =>
    schedules.where((spec) => spec.species == s).toList();
