import '../../core/dates.dart';
import '../data/schedules.dart';
import '../models/livestock.dart';

enum ScheduleState { overdue, dueSoon, noRecord, upToDate, completed }

/// Where one animal stands on one scheduled vaccination or deworming.
class ScheduleStatus {
  final Animal animal;
  final ScheduleSpec spec;
  final DateTime? lastGiven;
  final DateTime? dueOn;
  final ScheduleState state;

  const ScheduleStatus({
    required this.animal,
    required this.spec,
    required this.lastGiven,
    required this.dueOn,
    required this.state,
  });
}

/// How far ahead "due soon" looks. Two weeks is enough time to buy a
/// vaccine and arrange a visit.
const dueSoonDays = 14;

/// Schedule status for every vaccination and deworming that applies to
/// [animal], as of [on].
List<ScheduleStatus> scheduleFor(
  Animal animal,
  Iterable<HealthEvent> events,
  DateTime on, {
  List<ScheduleSpec> specs = schedules,
}) {
  final mine = events.where((e) => e.animalId == animal.id).toList();
  final result = <ScheduleStatus>[];

  for (final spec in specs.where((s) => s.species == animal.species)) {
    HealthEvent? last;
    for (final e in mine) {
      if (spec.matches(e) && (last == null || e.date.isAfter(last.date))) {
        last = e;
      }
    }

    if (last != null && spec.oneOff) {
      result.add(ScheduleStatus(
        animal: animal,
        spec: spec,
        lastGiven: last.date,
        dueOn: null,
        state: ScheduleState.completed,
      ));
      continue;
    }

    DateTime? due;
    if (last != null) {
      due = addDays(last.date, spec.intervalDays);
    } else if (animal.birthDate != null && spec.firstAtAgeDays != null) {
      due = addDays(animal.birthDate!, spec.firstAtAgeDays!);
    }

    final ScheduleState state;
    if (due == null) {
      // Never given, and no birth date to work from. Asking beats guessing.
      state = ScheduleState.noRecord;
    } else {
      final days = daysBetween(on, due);
      if (days < 0) {
        state = ScheduleState.overdue;
      } else if (days <= dueSoonDays) {
        state = ScheduleState.dueSoon;
      } else {
        state = ScheduleState.upToDate;
      }
    }

    result.add(ScheduleStatus(
      animal: animal,
      spec: spec,
      lastGiven: last?.date,
      dueOn: due,
      state: state,
    ));
  }

  return result;
}

/// A product that must not be used yet because of a recent treatment.
class WithdrawalHold {
  final Animal animal;
  final Product product;
  final DateTime safeFrom;
  final HealthEvent cause;

  const WithdrawalHold({
    required this.animal,
    required this.product,
    required this.safeFrom,
    required this.cause,
  });

  int daysLeft(DateTime on) => daysBetween(on, safeFrom);
}

/// Active withdrawal holds for [animal] on [on] — at most one per
/// product, the one that runs longest.
///
/// Events dated after [on] are ignored, so this also answers "was this
/// milk safe on that day?" when a past day's production is recorded.
List<WithdrawalHold> withdrawalsFor(
  Animal animal,
  Iterable<HealthEvent> events,
  DateTime on,
) {
  final day = dayOf(on);
  final holds = <WithdrawalHold>[];

  for (final product in [animal.species.dailyProduct, Product.meat]) {
    WithdrawalHold? longest;
    for (final e in events) {
      if (e.animalId != animal.id) continue;
      if (dayOf(e.date).isAfter(day)) continue;

      final safe = e.safeFrom(product);
      if (safe == null || !day.isBefore(safe)) continue;

      if (longest == null || safe.isAfter(longest.safeFrom)) {
        longest = WithdrawalHold(
          animal: animal,
          product: product,
          safeFrom: safe,
          cause: e,
        );
      }
    }
    if (longest != null) holds.add(longest);
  }

  return holds;
}

/// The hold on [product] for [animal] on [on], if any.
WithdrawalHold? holdOn(
  Animal animal,
  Product product,
  Iterable<HealthEvent> events,
  DateTime on,
) {
  for (final h in withdrawalsFor(animal, events, on)) {
    if (h.product == product) return h;
  }
  return null;
}
