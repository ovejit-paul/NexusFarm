import '../../core/dates.dart';
import 'livestock.dart';

enum EntryKind { income, expense }

enum LedgerCategory { crops, cattle, goat, chicken, duck, general }

extension LedgerCategoryInfo on LedgerCategory {
  String get label => switch (this) {
        LedgerCategory.crops => 'Crops',
        LedgerCategory.cattle => 'Cattle',
        LedgerCategory.goat => 'Goats',
        LedgerCategory.chicken => 'Chickens',
        LedgerCategory.duck => 'Ducks',
        LedgerCategory.general => 'General',
      };
}

LedgerCategory categoryForSpecies(Species s) => switch (s) {
      Species.cattle => LedgerCategory.cattle,
      Species.goat => LedgerCategory.goat,
      Species.chicken => LedgerCategory.chicken,
      Species.duck => LedgerCategory.duck,
    };

/// One line in the farm's single account.
///
/// Crops and animals share one ledger on purpose: a farmer who keeps both
/// has one household budget, and seeing pesticide next to cattle feed is
/// the point.
class LedgerEntry {
  final String id;
  final EntryKind kind;
  final LedgerCategory category;
  final double amount;
  final DateTime date;
  final String note;

  /// Set when the entry was created automatically from a health record
  /// or spray record, so deleting that record removes its cost too.
  final String? sourceId;

  const LedgerEntry({
    required this.id,
    required this.kind,
    required this.category,
    required this.amount,
    required this.date,
    this.note = '',
    this.sourceId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'category': category.name,
        'amount': amount,
        'date': isoDay(date),
        'note': note,
        'sourceId': sourceId,
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
        id: j['id'] as String,
        kind: EntryKind.values.byName(j['kind'] as String),
        category: LedgerCategory.values.byName(j['category'] as String),
        amount: (j['amount'] as num).toDouble(),
        date: parseDay(j['date'] as String),
        note: j['note'] as String? ?? '',
        sourceId: j['sourceId'] as String?,
      );
}

class CategoryTotals {
  double income = 0;
  double expense = 0;
  double get net => income - expense;
}

class LedgerSummary {
  final double income;
  final double expense;
  final Map<LedgerCategory, CategoryTotals> byCategory;
  final int count;

  const LedgerSummary({
    required this.income,
    required this.expense,
    required this.byCategory,
    required this.count,
  });

  double get net => income - expense;
}

/// Totals for entries between [from] and [to], both inclusive.
LedgerSummary summarize(
  Iterable<LedgerEntry> entries, {
  DateTime? from,
  DateTime? to,
}) {
  var income = 0.0;
  var expense = 0.0;
  var count = 0;
  final byCategory = <LedgerCategory, CategoryTotals>{};
  final start = from == null ? null : dayOf(from);
  final end = to == null ? null : dayOf(to);

  for (final e in entries) {
    final d = dayOf(e.date);
    if (start != null && d.isBefore(start)) continue;
    if (end != null && d.isAfter(end)) continue;

    count++;
    final totals = byCategory.putIfAbsent(e.category, CategoryTotals.new);
    if (e.kind == EntryKind.income) {
      income += e.amount;
      totals.income += e.amount;
    } else {
      expense += e.amount;
      totals.expense += e.amount;
    }
  }

  return LedgerSummary(
    income: income,
    expense: expense,
    byCategory: byCategory,
    count: count,
  );
}
