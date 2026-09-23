import '../models/crop_treatment.dart';
import '../models/ledger.dart';
import '../models/livestock.dart';

/// Everything the farm module stores, in one serialisable object.
///
/// Kept separate from [FarmStore] so the data and its JSON format can be
/// tested without Flutter or device storage.
class FarmData {
  /// Bump this when the stored shape changes, and add a step to
  /// [_migrate]. Old phones must keep opening their records.
  static const schemaVersion = 1;

  final List<Animal> animals;
  final List<HealthEvent> healthEvents;
  final List<ProductionLog> production;
  final List<LedgerEntry> ledger;
  final List<CropTreatment> cropTreatments;

  FarmData({
    List<Animal>? animals,
    List<HealthEvent>? healthEvents,
    List<ProductionLog>? production,
    List<LedgerEntry>? ledger,
    List<CropTreatment>? cropTreatments,
  })  : animals = animals ?? [],
        healthEvents = healthEvents ?? [],
        production = production ?? [],
        ledger = ledger ?? [],
        cropTreatments = cropTreatments ?? [];

  bool get isEmpty =>
      animals.isEmpty &&
      healthEvents.isEmpty &&
      production.isEmpty &&
      ledger.isEmpty &&
      cropTreatments.isEmpty;

  Animal? animalById(String id) {
    for (final a in animals) {
      if (a.id == id) return a;
    }
    return null;
  }

  Iterable<HealthEvent> eventsFor(String animalId) =>
      healthEvents.where((e) => e.animalId == animalId);

  Iterable<ProductionLog> productionFor(String animalId) =>
      production.where((p) => p.animalId == animalId);

  Map<String, dynamic> toJson() => {
        'schema': schemaVersion,
        'animals': animals.map((e) => e.toJson()).toList(),
        'healthEvents': healthEvents.map((e) => e.toJson()).toList(),
        'production': production.map((e) => e.toJson()).toList(),
        'ledger': ledger.map((e) => e.toJson()).toList(),
        'cropTreatments': cropTreatments.map((e) => e.toJson()).toList(),
      };

  /// Throws [FormatException] for anything that is not a valid NexusFarm
  /// record — including a backup from a newer version of the app, which
  /// this version cannot safely read.
  factory FarmData.fromJson(Map<String, dynamic> json) {
    final version = (json['schema'] as num?)?.toInt() ?? 1;
    if (version > schemaVersion) {
      throw FormatException(
        'These records come from a newer version of NexusFarm '
        '(format $version). Update the app to open them.',
      );
    }

    final j = _migrate(json, version);

    List<T> read<T>(String key, T Function(Map<String, dynamic>) parse) {
      final raw = j[key];
      if (raw == null) return [];
      if (raw is! List) throw FormatException('"$key" is not a list');
      return raw
          .map((e) => parse(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    try {
      return FarmData(
        animals: read('animals', Animal.fromJson),
        healthEvents: read('healthEvents', HealthEvent.fromJson),
        production: read('production', ProductionLog.fromJson),
        ledger: read('ledger', LedgerEntry.fromJson),
        cropTreatments: read('cropTreatments', CropTreatment.fromJson),
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      // Wrong types, missing fields, unknown enum names — all mean the
      // same thing to the user: this is not a readable record.
      throw FormatException('Records could not be read: $e');
    }
  }

  /// Upgrades older stored shapes to the current one. Nothing to do yet;
  /// this is where version 2 will convert version 1.
  static Map<String, dynamic> _migrate(
    Map<String, dynamic> json,
    int fromVersion,
  ) =>
      json;
}
