import 'package:flutter_test/flutter_test.dart';
import 'package:nexusfarm/core/dates.dart';
import 'package:nexusfarm/core/format.dart';

void main() {
  group('calendar days', () {
    test('addDays and daysBetween agree', () {
      final d = DateTime.utc(2026, 3, 1);
      expect(addDays(d, 180), DateTime.utc(2026, 8, 28));
      expect(daysBetween(d, DateTime.utc(2026, 8, 28)), 180);
      expect(daysBetween(DateTime.utc(2026, 8, 28), d), -180);
    });

    test('month ends, including leap years and December', () {
      expect(monthEnd(DateTime.utc(2026, 2, 10)), DateTime.utc(2026, 2, 28));
      expect(monthEnd(DateTime.utc(2028, 2, 10)), DateTime.utc(2028, 2, 29));
      expect(monthEnd(DateTime.utc(2026, 12, 5)), DateTime.utc(2026, 12, 31));
      expect(addMonths(DateTime.utc(2026, 12, 1), 1), DateTime.utc(2027, 1, 1));
      expect(addMonths(DateTime.utc(2026, 1, 1), -1), DateTime.utc(2025, 12, 1));
    });

    test('iso round trip', () {
      final d = DateTime.utc(2026, 9, 4);
      expect(isoDay(d), '2026-09-04');
      expect(parseDay('2026-09-04'), d);
    });

    test('dayOf drops the time of day', () {
      expect(dayOf(DateTime(2026, 9, 4, 23, 59)), DateTime.utc(2026, 9, 4));
    });

    test('relative wording', () {
      final base = DateTime.utc(2026, 9, 10);
      expect(relativeDay(base, from: base), 'today');
      expect(relativeDay(addDays(base, 1), from: base), 'tomorrow');
      expect(relativeDay(addDays(base, -1), from: base), 'yesterday');
      expect(relativeDay(addDays(base, 5), from: base), 'in 5 days');
      expect(relativeDay(addDays(base, -3), from: base), '3 days ago');
    });
  });

  group('formatting', () {
    test('taka groups thousands', () {
      expect(formatTaka(0), 'Tk 0');
      expect(formatTaka(950), 'Tk 950');
      expect(formatTaka(12450), 'Tk 12,450');
      expect(formatTaka(1234567), 'Tk 1,234,567');
      expect(formatTaka(-3200), '-Tk 3,200');
    });

    test('quantities drop a pointless .0', () {
      expect(formatQty(12), '12');
      expect(formatQty(2.5), '2.5');
    });
  });
}
