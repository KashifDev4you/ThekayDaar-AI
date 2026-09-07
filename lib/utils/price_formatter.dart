// PAKISTANI-STYLE PRICE SHORTHAND HELPER
// =============================================================================
// Usage: wherever you show a rupee amount, wrap it:
//
//   Text('Rs ${formatPriceShort(d['budgetMin'])}')
//
// Accepts a num, a numeric String (with or without commas), or null.
// Rules:
//   < 1,00,000        -> plain comma-formatted number   e.g. 45,000
//   >= 1,00,000        -> X Lac / X.X Lac                e.g. 1 Lac, 2.5 Lac
//   >= 1,00,00,000     -> X Cr / X.X Cr                  e.g. 1 Cr, 1.2 Cr
// =============================================================================
String formatPriceShort(dynamic value) {
  final amount = _toDouble(value);
  if (amount == null) return value?.toString() ?? '';

  if (amount >= 10000000) {
    return '${_trimZero(amount / 10000000)} Cr';
  } else if (amount >= 100000) {
    return '${_trimZero(amount / 100000)} Lac';
  } else {
    return _commaFormat(amount);
  }
}

double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '').trim());
  }
  return null;
}

String _trimZero(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1);
}

String _commaFormat(double v) {
  final intVal = v.round();
  return intVal.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
}