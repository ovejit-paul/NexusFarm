import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/dates.dart';
import '../../core/ids.dart';
import '../logic/livestock_logic.dart';
import '../models/crop_treatment.dart';
import '../models/ledger.dart';
import '../models/livestock.dart';
import 'farm_data.dart';

/// Holds the farm records and saves every change to the device.
///
/// Storage is shared_preferences because it works identically on
/// Android and in a browser. A smallholding produces hundreds of records
/// a year, not millions, so a single JSON document is comfortably
/// enough; a database would add a dependency that behaves differently
/// on web without giving anything back at this size.
class FarmStore extends ChangeNotifier {
  FarmStore._();
  static final FarmStore instance = FarmStore._();

  static const _key = 'farm_data';
  static const _corruptKey = 'farm_data_unreadable_backup';

  FarmData _data = FarmData();
  SharedPreferences? _prefs;

  /// Set when stored records could not be read on startup. The unreadable
  /// copy is kept, never silently thrown away.
  String? loadError;

  FarmData get data => _data;

  String? get unreadableBackup => _prefs?.getString(_corruptKey);

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_key);
      if (raw != null) {
        try {
          _data = FarmData.fromJson(
              Map<String, dynamic>.from(jsonDecode(raw) as Map));
          loadError = null;
        } catch (e) {
          // Keep the damaged copy so nothing is lost for good, and start
          // fresh so the app still opens.
          await _prefs!.setString(_corruptKey, raw);
          loadError = 'Your saved farm records could not be read. A copy '
              'has been kept — see Tools › Backup.';
          _data = FarmData();
        }
      }
    } catch (_) {
      // Storage itself unavailable. Run from memory rather than not at all.
    }
    notifyListeners();
  }

  Future<void> _commit() async {
    notifyListeners();
    try {
      await _prefs?.setString(_key, jsonEncode(_data.toJson()));
    } catch (_) {
      // A failed write should not crash the screen the farmer is using.
    }
  }

  // ---------------------------------------------------------------
  // Animals
  // ---------------------------------------------------------------

  Future<void> saveAnimal(Animal animal) async {
    final i = _data.animals.indexWhere((a) => a.id == animal.id);
    if (i >= 0) {
      _data.animals[i] = animal;
    } else {
      _data.animals.add(animal);
    }
    await _commit();
  }

  /// Removes the animal and everything recorded against it, including
  /// the ledger entries that came from its treatments.
  Future<void> deleteAnimal(String id) async {
    final eventIds = _data.healthEvents
        .where((e) => e.animalId == id)
        .map((e) => e.id)
        .toSet();
    _data.animals.removeWhere((a) => a.id == id);
    _data.healthEvents.removeWhere((e) => e.animalId == id);
    _data.production.removeWhere((p) => p.animalId == id);
    _data.ledger.removeWhere(
        (l) => l.sourceId != null && eventIds.contains(l.sourceId));
    await _commit();
  }

  // ---------------------------------------------------------------
  // Health
  // ---------------------------------------------------------------

  /// Records a health event. A cost above zero also goes into the ledger
  /// as an expense, linked back so deleting one deletes the other.
  Future<void> addHealthEvent(HealthEvent event) async {
    _data.healthEvents.add(event);

    final animal = _data.animalById(event.animalId);
    if (event.cost > 0 && animal != null) {
      _data.ledger.add(LedgerEntry(
        id: newId(),
        kind: EntryKind.expense,
        category: categoryForSpecies(animal.species),
        amount: event.cost,
        date: event.date,
        note: '${event.type.label}: ${event.name} · ${animal.name}',
        sourceId: event.id,
      ));
    }
    await _commit();
  }

  Future<void> deleteHealthEvent(String id) async {
    _data.healthEvents.removeWhere((e) => e.id == id);
    _data.ledger.removeWhere((l) => l.sourceId == id);
    await _commit();
  }

  // ---------------------------------------------------------------
  // Production
  // ---------------------------------------------------------------

  /// Records milk or eggs. If a withdrawal period covers that day the
  /// log is marked discarded — kept for the record, never counted as
  /// usable, whatever the farmer typed.
  Future<ProductionLog> addProduction({
    required Animal animal,
    required DateTime date,
    required double quantity,
  }) async {
    final product = animal.species.dailyProduct;
    final hold = holdOn(animal, product, _data.healthEvents, date);
    final log = ProductionLog(
      id: newId(),
      animalId: animal.id,
      date: dayOf(date),
      product: product,
      quantity: quantity,
      discarded: hold != null,
    );
    _data.production.add(log);
    await _commit();
    return log;
  }

  Future<void> deleteProduction(String id) async {
    _data.production.removeWhere((p) => p.id == id);
    await _commit();
  }

  // ---------------------------------------------------------------
  // Ledger
  // ---------------------------------------------------------------

  Future<void> addLedgerEntry(LedgerEntry entry) async {
    _data.ledger.add(entry);
    await _commit();
  }

  Future<void> deleteLedgerEntry(String id) async {
    _data.ledger.removeWhere((l) => l.id == id);
    await _commit();
  }

  // ---------------------------------------------------------------
  // Crop spray records
  // ---------------------------------------------------------------

  Future<void> addCropTreatment(CropTreatment t) async {
    _data.cropTreatments.add(t);
    if (t.cost > 0) {
      _data.ledger.add(LedgerEntry(
        id: newId(),
        kind: EntryKind.expense,
        category: LedgerCategory.crops,
        amount: t.cost,
        date: t.date,
        note: 'Spray: ${t.product} · ${t.displayName}',
        sourceId: t.id,
      ));
    }
    await _commit();
  }

  Future<void> deleteCropTreatment(String id) async {
    _data.cropTreatments.removeWhere((t) => t.id == id);
    _data.ledger.removeWhere((l) => l.sourceId == id);
    await _commit();
  }

  // ---------------------------------------------------------------
  // Backup
  // ---------------------------------------------------------------

  String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(_data.toJson());

  /// Replaces all records with a backup. Validates everything first, so a
  /// bad paste leaves the current records untouched.
  Future<void> importJson(String raw) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw.trim());
    } catch (_) {
      throw const FormatException('That is not a NexusFarm backup.');
    }
    if (decoded is! Map) {
      throw const FormatException('That is not a NexusFarm backup.');
    }
    final incoming = FarmData.fromJson(Map<String, dynamic>.from(decoded));
    _data = incoming;
    loadError = null;
    await _commit();
  }

  Future<void> clearUnreadableBackup() async {
    await _prefs?.remove(_corruptKey);
    loadError = null;
    notifyListeners();
  }

  @visibleForTesting
  Future<void> resetForTest() async {
    _data = FarmData();
    loadError = null;
    _prefs = null;
    await load();
  }
}
