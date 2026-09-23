import 'package:flutter_test/flutter_test.dart';
import 'package:nexusfarm/farm/data/schedules.dart';
import 'package:nexusfarm/farm/logic/livestock_logic.dart';
import 'package:nexusfarm/farm/models/livestock.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

Animal cow({DateTime? birth}) => Animal(
      id: 'cow1',
      species: Species.cattle,
      name: 'Lali',
      birthDate: birth,
      producing: true,
      createdAt: d(2026, 1, 1),
    );

Animal flock() => Animal(
      id: 'flock1',
      species: Species.chicken,
      name: 'Layers',
      headCount: 40,
      producing: true,
      createdAt: d(2026, 1, 1),
    );

HealthEvent vaccine(String animalId, String name, DateTime on) => HealthEvent(
      id: '$animalId-$name-$on',
      animalId: animalId,
      type: HealthEventType.vaccination,
      name: name,
      date: on,
    );

ScheduleStatus statusOf(List<ScheduleStatus> all, String name) =>
    all.firstWhere((s) => s.spec.name == name);

void main() {
  const fmd = 'FMD (foot-and-mouth)';

  group('vaccination schedule', () {
    test('due date is last dose plus interval', () {
      final events = [vaccine('cow1', fmd, d(2026, 3, 1))];
      final s = statusOf(scheduleFor(cow(), events, d(2026, 6, 1)), fmd);
      expect(s.dueOn, d(2026, 8, 28));
      expect(s.state, ScheduleState.upToDate);
    });

    test('within 14 days is due soon, past the date is overdue', () {
      final events = [vaccine('cow1', fmd, d(2026, 3, 1))];
      expect(statusOf(scheduleFor(cow(), events, d(2026, 8, 20)), fmd).state,
          ScheduleState.dueSoon);
      expect(statusOf(scheduleFor(cow(), events, d(2026, 8, 28)), fmd).state,
          ScheduleState.dueSoon, reason: 'the due day itself is not late');
      expect(statusOf(scheduleFor(cow(), events, d(2026, 9, 10)), fmd).state,
          ScheduleState.overdue);
    });

    test('latest dose wins when several are recorded', () {
      final events = [
        vaccine('cow1', fmd, d(2025, 9, 1)),
        vaccine('cow1', fmd, d(2026, 3, 1)),
      ];
      final s = statusOf(scheduleFor(cow(), events, d(2026, 6, 1)), fmd);
      expect(s.lastGiven, d(2026, 3, 1));
    });

    test('without a dose, the first is scheduled from birth date', () {
      final s = statusOf(
          scheduleFor(cow(birth: d(2026, 1, 1)), const [], d(2026, 3, 1)), fmd);
      expect(s.dueOn, d(2026, 5, 1));
    });

    test('without a dose or birth date, it asks rather than guesses', () {
      final s = statusOf(scheduleFor(cow(), const [], d(2026, 3, 1)), fmd);
      expect(s.state, ScheduleState.noRecord);
      expect(s.dueOn, isNull);
    });

    test('a vaccine only matches its own name', () {
      final events = [vaccine('cow1', 'Anthrax', d(2026, 3, 1))];
      final s = statusOf(scheduleFor(cow(), events, d(2026, 3, 5)), fmd);
      expect(s.state, ScheduleState.noRecord);
    });

    test('another animal\'s dose does not count', () {
      final events = [vaccine('someone-else', fmd, d(2026, 3, 1))];
      final s = statusOf(scheduleFor(cow(), events, d(2026, 3, 5)), fmd);
      expect(s.state, ScheduleState.noRecord);
    });

    test('any dewormer resets the deworming clock', () {
      final events = [
        HealthEvent(
          id: 'w',
          animalId: 'cow1',
          type: HealthEventType.deworming,
          name: 'Albendazole',
          date: d(2026, 3, 1),
        ),
      ];
      final s = statusOf(scheduleFor(cow(), events, d(2026, 3, 5)), 'Deworming');
      expect(s.lastGiven, d(2026, 3, 1));
      expect(s.dueOn, d(2026, 6, 29));
    });

    test('a single-dose vaccine is completed once given', () {
      final events = [vaccine('flock1', 'Gumboro (IBD)', d(2026, 2, 1))];
      final s = statusOf(
          scheduleFor(flock(), events, d(2026, 9, 1)), 'Gumboro (IBD)');
      expect(s.state, ScheduleState.completed);
    });

    test('every species has at least one schedule', () {
      for (final species in Species.values) {
        expect(schedulesFor(species), isNotEmpty, reason: species.label);
      }
    });
  });

  group('withdrawal periods', () {
    final treatment = HealthEvent(
      id: 't1',
      animalId: 'cow1',
      type: HealthEventType.treatment,
      name: 'Oxytetracycline',
      date: d(2026, 9, 1),
      milkWithdrawalDays: 7,
      meatWithdrawalDays: 28,
    );

    test('milk and meat are both held, each until its own date', () {
      final holds = withdrawalsFor(cow(), [treatment], d(2026, 9, 5));
      final milk = holds.firstWhere((h) => h.product == Product.milk);
      final meat = holds.firstWhere((h) => h.product == Product.meat);
      expect(milk.safeFrom, d(2026, 9, 8));
      expect(milk.daysLeft(d(2026, 9, 5)), 3);
      expect(meat.safeFrom, d(2026, 9, 29));
    });

    test('the hold ends on the safe-from day, not the day after', () {
      expect(holdOn(cow(), Product.milk, [treatment], d(2026, 9, 7)), isNotNull);
      expect(holdOn(cow(), Product.milk, [treatment], d(2026, 9, 8)), isNull);
      expect(holdOn(cow(), Product.meat, [treatment], d(2026, 9, 8)), isNotNull);
    });

    test('the treatment day itself is held', () {
      expect(holdOn(cow(), Product.milk, [treatment], d(2026, 9, 1)), isNotNull);
    });

    test('a future-dated treatment does not hold today', () {
      expect(holdOn(cow(), Product.milk, [treatment], d(2026, 8, 30)), isNull);
    });

    test('with two treatments, the longer hold wins', () {
      final second = HealthEvent(
        id: 't2',
        animalId: 'cow1',
        type: HealthEventType.treatment,
        name: 'Penicillin',
        date: d(2026, 9, 3),
        milkWithdrawalDays: 4,
      );
      final h = holdOn(cow(), Product.milk, [treatment, second], d(2026, 9, 4));
      expect(h!.safeFrom, d(2026, 9, 8));
      expect(h.cause.id, 't1');
    });

    test('poultry are held on eggs, not milk', () {
      final e = HealthEvent(
        id: 'p',
        animalId: 'flock1',
        type: HealthEventType.treatment,
        name: 'Enrofloxacin',
        date: d(2026, 9, 1),
        eggWithdrawalDays: 10,
      );
      final holds = withdrawalsFor(flock(), [e], d(2026, 9, 5));
      expect(holds.single.product, Product.eggs);
      expect(holds.single.safeFrom, d(2026, 9, 11));
    });

    test('zero withdrawal means no hold', () {
      final v = vaccine('cow1', fmd, d(2026, 9, 1));
      expect(withdrawalsFor(cow(), [v], d(2026, 9, 1)), isEmpty);
    });
  });
}
