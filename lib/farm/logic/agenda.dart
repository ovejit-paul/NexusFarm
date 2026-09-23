import '../../core/dates.dart';
import '../models/livestock.dart';
import '../store/farm_data.dart';
import 'livestock_logic.dart';

enum AgendaPriority { urgent, soon, info }

enum AgendaKind { withdrawal, harvestHold, overdue, dueSoon, missingRecords }

/// One line on the Today screen.
class AgendaItem {
  final AgendaKind kind;
  final AgendaPriority priority;
  final String title;
  final String detail;
  final DateTime? date;
  final String? animalId;

  const AgendaItem({
    required this.kind,
    required this.priority,
    required this.title,
    required this.detail,
    this.date,
    this.animalId,
  });

  bool get isHold =>
      kind == AgendaKind.withdrawal || kind == AgendaKind.harvestHold;
}

/// Everything that needs the farmer's attention, most urgent first.
///
/// Holds come before vaccines: a vaccine a few days late is a risk to
/// the animal, but selling milk during a withdrawal period is a risk to
/// whoever drinks it.
List<AgendaItem> buildAgenda(FarmData data, DateTime on) {
  final items = <AgendaItem>[];

  for (final animal in data.animals) {
    for (final hold in withdrawalsFor(animal, data.healthEvents, on)) {
      items.add(AgendaItem(
        kind: AgendaKind.withdrawal,
        priority: AgendaPriority.urgent,
        title: hold.product.holdAction(animal.name),
        detail: 'Safe from ${formatDay(hold.safeFrom)} '
            '(${relativeDay(hold.safeFrom, from: on)}) · after ${hold.cause.name}',
        date: hold.safeFrom,
        animalId: animal.id,
      ));
    }

    var missing = 0;
    for (final s in scheduleFor(animal, data.healthEvents, on)) {
      switch (s.state) {
        case ScheduleState.overdue:
          items.add(AgendaItem(
            kind: AgendaKind.overdue,
            priority: AgendaPriority.urgent,
            title: '${s.spec.name} overdue · ${animal.name}',
            detail: 'Was due ${formatDay(s.dueOn!)} '
                '(${relativeDay(s.dueOn!, from: on)})',
            date: s.dueOn,
            animalId: animal.id,
          ));
        case ScheduleState.dueSoon:
          items.add(AgendaItem(
            kind: AgendaKind.dueSoon,
            priority: AgendaPriority.soon,
            title: '${s.spec.name} · ${animal.name}',
            detail: 'Due ${formatDay(s.dueOn!)} '
                '(${relativeDay(s.dueOn!, from: on)})',
            date: s.dueOn,
            animalId: animal.id,
          ));
        case ScheduleState.noRecord:
          missing++;
        case ScheduleState.upToDate:
        case ScheduleState.completed:
          break;
      }
    }

    // Collapsed to one line per animal. A new user with ten animals would
    // otherwise face forty "no record" rows and learn to ignore the screen.
    if (missing > 0) {
      items.add(AgendaItem(
        kind: AgendaKind.missingRecords,
        priority: AgendaPriority.info,
        title: 'No vaccination records · ${animal.name}',
        detail: '$missing scheduled '
            '${missing == 1 ? 'item has' : 'items have'} never been recorded. '
            'Add past doses, or a ${animal.species.dateLabel.toLowerCase()}.',
        animalId: animal.id,
      ));
    }
  }

  for (final t in data.cropTreatments) {
    if (!t.isHoldActive(on)) continue;
    items.add(AgendaItem(
      kind: AgendaKind.harvestHold,
      priority: AgendaPriority.urgent,
      title: 'Do not harvest ${t.displayName}',
      detail: 'Sprayed ${t.product} on ${formatDay(t.date)} · safe from '
          '${formatDay(t.safeHarvestFrom)} '
          '(${relativeDay(t.safeHarvestFrom, from: on)})',
      date: t.safeHarvestFrom,
    ));
  }

  final never = DateTime.utc(9999);
  items.sort((a, b) {
    final byPriority = a.priority.index.compareTo(b.priority.index);
    if (byPriority != 0) return byPriority;
    // Holds before other urgent items; then soonest date first.
    if (a.isHold != b.isHold) return a.isHold ? -1 : 1;
    return (a.date ?? never).compareTo(b.date ?? never);
  });

  return items;
}

/// Number of active holds, for the summary tile.
int activeHoldCount(FarmData data, DateTime on) {
  var n = 0;
  for (final a in data.animals) {
    n += withdrawalsFor(a, data.healthEvents, on).length;
  }
  for (final t in data.cropTreatments) {
    if (t.isHoldActive(on)) n++;
  }
  return n;
}

/// Usable and discarded totals of [product] for [animalId] over the
/// last [days] days ending on [on].
({double usable, double discarded}) productionTotals(
  FarmData data,
  String animalId,
  Product product,
  DateTime on, {
  int days = 7,
}) {
  final from = addDays(on, -(days - 1));
  var usable = 0.0;
  var discarded = 0.0;
  for (final log in data.production) {
    if (log.animalId != animalId || log.product != product) continue;
    final d = dayOf(log.date);
    if (d.isBefore(from) || d.isAfter(dayOf(on))) continue;
    if (log.discarded) {
      discarded += log.quantity;
    } else {
      usable += log.quantity;
    }
  }
  return (usable: usable, discarded: discarded);
}
