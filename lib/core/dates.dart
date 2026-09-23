/// Calendar-day arithmetic.
///
/// Every date in the farm records is a calendar day, not an instant. They
/// are held as UTC midnight so that adding days is exact: in local time,
/// "seven days after" can come out 23 or 25 hours long across a daylight
/// saving change, and a withdrawal period is not something to get wrong
/// by a day.
library;

/// The calendar day of [d], as UTC midnight.
DateTime dayOf(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Today, as a calendar day.
DateTime today() => dayOf(DateTime.now());

DateTime addDays(DateTime d, int days) => dayOf(d).add(Duration(days: days));

/// Whole days from [from] to [to]. Negative when [to] is earlier.
int daysBetween(DateTime from, DateTime to) =>
    dayOf(to).difference(dayOf(from)).inDays;

DateTime monthStart(DateTime d) => DateTime.utc(d.year, d.month, 1);

/// Last day of the month. Day 0 of the next month is the last day of
/// this one, and DateTime rolls December into January on its own.
DateTime monthEnd(DateTime d) => DateTime.utc(d.year, d.month + 1, 0);

DateTime addMonths(DateTime d, int months) =>
    DateTime.utc(d.year, d.month + months, 1);

/// Storage format: 2026-09-24.
String isoDay(DateTime d) {
  final x = dayOf(d);
  return '${x.year.toString().padLeft(4, '0')}-'
      '${x.month.toString().padLeft(2, '0')}-'
      '${x.day.toString().padLeft(2, '0')}';
}

DateTime parseDay(String s) {
  final p = DateTime.parse(s);
  return DateTime.utc(p.year, p.month, p.day);
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _monthsLong = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Display format: 24 Sep 2026.
String formatDay(DateTime d) {
  final x = dayOf(d);
  return '${x.day} ${_months[x.month - 1]} ${x.year}';
}

/// Display format: September 2026.
String formatMonth(DateTime d) => '${_monthsLong[d.month - 1]} ${d.year}';

/// "today", "tomorrow", "in 3 days", "2 days ago".
String relativeDay(DateTime d, {DateTime? from}) {
  final n = daysBetween(from ?? today(), d);
  if (n == 0) return 'today';
  if (n == 1) return 'tomorrow';
  if (n == -1) return 'yesterday';
  return n > 0 ? 'in $n days' : '${-n} days ago';
}

/// Rough age for display: "3 weeks", "7 months", "2 years".
String formatAge(DateTime birth, {DateTime? on}) {
  final days = daysBetween(birth, on ?? today());
  if (days < 0) return 'not born yet';
  if (days < 14) return '$days ${days == 1 ? 'day' : 'days'}';
  if (days < 60) return '${days ~/ 7} weeks';
  if (days < 730) return '${days ~/ 30} months';
  return '${days ~/ 365} years';
}
