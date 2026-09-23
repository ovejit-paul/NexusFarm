/// Money and quantity formatting for display.
library;

/// Tk 12,450 — whole taka, thousands grouped. Paisa are not worth the
/// screen space on a farm ledger.
String formatTaka(double value) {
  final negative = value < 0;
  final digits = value.abs().round().toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return '${negative ? '-' : ''}Tk $grouped';
}

/// 12 rather than 12.0; 2.5 stays 2.5.
String formatQty(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);
