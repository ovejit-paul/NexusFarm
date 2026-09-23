import 'package:flutter_test/flutter_test.dart';
import 'package:nexusfarm/core/dates.dart';
import 'package:nexusfarm/farm/models/crop_treatment.dart';
import 'package:nexusfarm/farm/models/ledger.dart';
import 'package:nexusfarm/farm/models/livestock.dart';
import 'package:nexusfarm/farm/store/farm_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FarmStore store;
  final day = today();

  final cow = Animal(
    id: 'cow',
    species: Species.cattle,
    name: 'Lali',
    producing: true,
    createdAt: day,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = FarmStore.instance;
    await store.resetForTest();
  });

  test('a treatment cost goes into the ledger, and leaves with it', () async {
    await store.saveAnimal(cow);
    await store.addHealthEvent(HealthEvent(
      id: 'h1',
      animalId: 'cow',
      type: HealthEventType.treatment,
      name: 'Oxytetracycline',
      date: day,
      milkWithdrawalDays: 7,
      cost: 450,
    ));
    expect(store.data.ledger.single.amount, 450);
    expect(store.data.ledger.single.category, LedgerCategory.cattle);

    await store.deleteHealthEvent('h1');
    expect(store.data.ledger, isEmpty);
  });

  test('milk logged during withdrawal is marked discarded', () async {
    await store.saveAnimal(cow);
    await store.addHealthEvent(HealthEvent(
      id: 'h1',
      animalId: 'cow',
      type: HealthEventType.treatment,
      name: 'Oxytetracycline',
      date: day,
      milkWithdrawalDays: 7,
    ));
    final during = await store.addProduction(
        animal: cow, date: addDays(day, 2), quantity: 5);
    final after = await store.addProduction(
        animal: cow, date: addDays(day, 7), quantity: 5);
    expect(during.discarded, isTrue);
    expect(after.discarded, isFalse);
  });

  test('deleting an animal removes everything recorded against it',
      () async {
    await store.saveAnimal(cow);
    await store.addHealthEvent(HealthEvent(
      id: 'h1',
      animalId: 'cow',
      type: HealthEventType.vaccination,
      name: 'Anthrax',
      date: day,
      cost: 80,
    ));
    await store.addProduction(animal: cow, date: day, quantity: 4);
    await store.addLedgerEntry(LedgerEntry(
      id: 'manual',
      kind: EntryKind.expense,
      category: LedgerCategory.general,
      amount: 100,
      date: day,
    ));

    await store.deleteAnimal('cow');
    expect(store.data.animals, isEmpty);
    expect(store.data.healthEvents, isEmpty);
    expect(store.data.production, isEmpty);
    expect(store.data.ledger.single.id, 'manual',
        reason: 'unrelated entries stay');
  });

  test('records persist across a restart', () async {
    await store.saveAnimal(cow);
    await store.addCropTreatment(CropTreatment(
      id: 'c1',
      crop: 'Potato',
      product: 'Mancozeb',
      date: day,
      phiDays: 7,
      cost: 300,
    ));
    // Reload from the same mocked storage, as on the next app launch.
    await store.load();
    expect(store.data.animals.single.name, 'Lali');
    expect(store.data.cropTreatments.single.phiDays, 7);
    expect(store.data.ledger.single.category, LedgerCategory.crops);
  });

  test('a bad backup is rejected and current records are untouched',
      () async {
    await store.saveAnimal(cow);
    await expectLater(store.importJson('not json'), throwsFormatException);
    await expectLater(store.importJson('[1,2,3]'), throwsFormatException);
    await expectLater(
        store.importJson('{"schema": 99}'), throwsFormatException);
    expect(store.data.animals.single.id, 'cow');
  });

  test('export then import gives back the same records', () async {
    await store.saveAnimal(cow);
    final backup = store.exportJson();
    await store.deleteAnimal('cow');
    expect(store.data.animals, isEmpty);
    await store.importJson(backup);
    expect(store.data.animals.single.name, 'Lali');
  });

  test('unreadable stored data is kept aside, not thrown away', () async {
    SharedPreferences.setMockInitialValues({'farm_data': '{broken'});
    await store.resetForTest();
    expect(store.loadError, isNotNull);
    expect(store.unreadableBackup, '{broken');
    expect(store.data.isEmpty, isTrue);
  });
}
