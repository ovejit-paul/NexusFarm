import '../../core/dates.dart';

/// A pesticide or fungicide application on a crop, and the date its
/// harvest becomes safe again.
class CropTreatment {
  final String id;
  final String crop;
  final String plot;
  final String product;
  final DateTime date;

  /// Pre-harvest interval, from the product label.
  final int phiDays;
  final double cost;
  final String notes;

  const CropTreatment({
    required this.id,
    required this.crop,
    this.plot = '',
    required this.product,
    required this.date,
    required this.phiDays,
    this.cost = 0,
    this.notes = '',
  });

  DateTime get safeHarvestFrom => addDays(date, phiDays);

  /// True while harvesting would put residue into food. A spray dated
  /// after [on] has not happened yet, so it holds nothing on that day.
  bool isHoldActive(DateTime on) {
    final day = dayOf(on);
    return phiDays > 0 &&
        !day.isBefore(dayOf(date)) &&
        day.isBefore(safeHarvestFrom);
  }

  String get displayName => plot.isEmpty ? crop : '$crop ($plot)';

  Map<String, dynamic> toJson() => {
        'id': id,
        'crop': crop,
        'plot': plot,
        'product': product,
        'date': isoDay(date),
        'phiDays': phiDays,
        'cost': cost,
        'notes': notes,
      };

  factory CropTreatment.fromJson(Map<String, dynamic> j) => CropTreatment(
        id: j['id'] as String,
        crop: j['crop'] as String,
        plot: j['plot'] as String? ?? '',
        product: j['product'] as String,
        date: parseDay(j['date'] as String),
        phiDays: (j['phiDays'] as num).toInt(),
        cost: (j['cost'] as num?)?.toDouble() ?? 0,
        notes: j['notes'] as String? ?? '',
      );
}

/// Pulls the day count out of text like "Wait 7 days after spraying
/// before harvesting." so a diagnosis can pre-fill a spray record.
int? parsePhiDays(String text) {
  final match = RegExp(r'(\d+)\s*day', caseSensitive: false).firstMatch(text);
  return match == null ? null : int.tryParse(match.group(1)!);
}
