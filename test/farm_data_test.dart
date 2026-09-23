import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexusfarm/farm/logic/agenda.dart';
import 'package:nexusfarm/farm/models/crop_treatment.dart';
import 'package:nexusfarm/farm/models/ledger.dart';
import 'package:nexusfarm/farm/models/livestock.dart';
import 'package:nexusfarm/farm/store/farm_data.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

FarmData sample() => FarmData(
      animals: [
        Animal(
          id: 'a1',
          species: Species.cattle,
          name: 'Lali',
          birthDate: d(2024, 5, 1),
          producing: true,
          notes: 'Friesian cross',
          createdAt: d(2026, 1, 1),
        ),
        Animal(
          id: 'a2',
          species: Species.duck,
          name: 'Pond flock',
          headCount: 25,
          createdAt: d(2026, 1, 1),
        ),
      ],
      healthEvents: [
        HealthEvent(
          id: 'h1',
          animalId: 'a1',
          type: HealthEventType.treatment,
          name: 'Oxytetracycline',
          date: d(2026, 9, 1),
          milkWithdrawalDays: 7,
          meatWithdrawalDays: 28,
          cost: 450,
        ),
      ],
      production: [
        ProductionLog(
          id: 'p1',
          animalId: 'a1',
          date: d(2026, 9, 2),
          product: Product.milk,
          quantity: 6.5,
          discarded: true,
        ),
      ],
      ledger: [
        LedgerEntry(
          id: 'l1',
          kind: EntryKind.income,
          category: LedgerCategory.cattle,
          amount: 1200,
          date: d(2026, 9, 3),
          note: 'Milk sold',
        ),
      ],
      cropTreatments: [
        CropTreatment(
          id: 'c1',
          crop: 'Potato',
          plot: 'North field',
          product: 'Mancozeb',
          date: d(2026, 9, 10),
          phiDays: 7,
        ),
      ],
    );

void main() {
  group('storage format', () {
    test('survives a JSON round trip unchanged', () {
      final original = sample();
      final text = jsonEncode(original.toJson());
      final back = FarmData.fromJson(
          Map<String, dynamic>.from(jsonDecode(text) as Map));
      expect(jsonEncode(back.toJson()), text);
      expect(back.animals.first.birthDate, d(2024, 5, 1));
      expect(back.production.single.discarded, isTrue);
      expect(back.cropTreatments.single.safeHarvestFrom, d(2026, 9, 17));
    });

    test('an empty document opens as an empty farm', () {
      expect(FarmData.fromJson({'schema': 1}).isEmpty, isTrue);
      expect(FarmData.fromJson({}).isEmpty, isTrue);
    });

    test('records from a newer app version are refused, not misread', () {
      expect(() => FarmData.fromJson({'schema': FarmData.schemaVersion + 1}),
          throwsFormatException);
    });

    test('malformed records raise FormatException, never a crash', () {
      expect(() => FarmData.fromJson({'animals': 'not a list'}),
          throwsFormatException);
      expect(
          () => FarmData.fromJson({
                'animals': [
                  {'id': 'x', 'species': 'dragon', 'name': 'y',
                   'createdAt': '2026-01-01'}
                ]
              }),
          throwsFormatException);
      expect(() => FarmData.fromJson({'ledger': [{'id': 1}]}),
          throwsFormatException);
    });
  });

  group('ledger', () {
    final entries = [
      LedgerEntry(id: '1', kind: EntryKind.income, category: LedgerCategory.cattle,
          amount: 1000, date: d(2026, 9, 1)),
      LedgerEntry(id: '2', kind: EntryKind.expense, category: LedgerCategory.cattle,
          amount: 300, date: d(2026, 9, 15)),
      LedgerEntry(id: '3', kind: EntryKind.expense, category: LedgerCategory.crops,
          amount: 250, date: d(2026, 9, 30)),
      LedgerEntry(id: '4', kind: EntryKind.income, category: LedgerCategory.crops,
          amount: 5000, date: d(2026, 10, 1)),
    ];

    test('totals a month, both ends inclusive', () {
      final s = summarize(entries, from: d(2026, 9, 1), to: d(2026, 9, 30));
      expect(s.count, 3);
      expect(s.income, 1000);
      expect(s.expense, 550);
      expect(s.net, 450);
      expect(s.byCategory[LedgerCategory.cattle]!.net, 700);
      expect(s.byCategory[LedgerCategory.crops]!.net, -250);
    });

    test('without bounds, totals everything', () {
      expect(summarize(entries).net, 5450);
    });
  });

  group('spray records', () {
    test('pre-harvest interval is read from diagnosis text', () {
      expect(parsePhiDays('Wait 7 days after spraying before harvesting.'), 7);
      expect(parsePhiDays('Wait 21 days after spraying'), 21);
      expect(parsePhiDays('WAIT 35 DAYS'), 35);
      expect(parsePhiDays(''), isNull);
      expect(parsePhiDays('No treatment needed.'), isNull);
    });

    test('hold runs until the safe day', () {
      final t = sample().cropTreatments.single;
      expect(t.isHoldActive(d(2026, 9, 16)), isTrue);
      expect(t.isHoldActive(d(2026, 9, 17)), isFalse);
    });
  });

  group('today agenda', () {
    test('holds are listed first, crops and animals together', () {
      final items = buildAgenda(sample(), d(2026, 9, 12));
      final holds = items.takeWhile((i) => i.isHold).toList();
      expect(holds.map((i) => i.kind).toSet(),
          {AgendaKind.withdrawal, AgendaKind.harvestHold});
      expect(items.first.priority, AgendaPriority.urgent);
    });

    test('missing records collapse to one line per animal', () {
      final items = buildAgenda(sample(), d(2026, 9, 12));
      final missing =
          items.where((i) => i.kind == AgendaKind.missingRecords).toList();
      // The cow has a birth date so its schedule is computable; the duck
      // flock has none, so its items are missing — as a single line.
      expect(missing.where((i) => i.animalId == 'a2').length, 1);
    });

    test('hold count covers animal products and crops', () {
      // 5 Sep: cow milk (until 8 Sep) and meat (until 29 Sep). The potato
      // spray is dated 10 Sep, so it holds nothing yet.
      expect(activeHoldCount(sample(), d(2026, 9, 5)), 2);
      // 12 Sep: milk hold over; meat still held; potato held until 17 Sep.
      expect(activeHoldCount(sample(), d(2026, 9, 12)), 2);
      // 1 Oct: everything clear.
      expect(activeHoldCount(sample(), d(2026, 10, 1)), 0);
    });

    test('a spray does not hold the crop before it was sprayed', () {
      final t = sample().cropTreatments.single;
      expect(t.isHoldActive(d(2026, 9, 9)), isFalse);
      expect(t.isHoldActive(d(2026, 9, 10)), isTrue);
    });

    test('discarded milk is not counted as usable', () {
      final t = productionTotals(sample(), 'a1', Product.milk, d(2026, 9, 5));
      expect(t.usable, 0);
      expect(t.discarded, 6.5);
    });
  });
}
