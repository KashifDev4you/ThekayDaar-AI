// =============================================================================
// plot_units.dart — Pakistani land-measurement unit helpers
//
// Conversions used across the house planner (housing-society standard):
//   1 Marla       = 225 sq ft
//   1 Kanal       = 20 Marla = 4,500 sq ft
//   1 Sq Yard     = 9 sq ft  ("gaz" / "sqr yd" — the classic "120 gaj" house)
//
// The traditional revenue marla is 272.25 sq ft, but Pakistani housing
// schemes (DHA, CDA, LDA) allocate 225 sq ft — which also matches the
// wizard's built-in presets (5 Marla = 25 × 45 ft = 1,125 sq ft).
// =============================================================================

class PlotUnits {
  PlotUnits._();

  static const double sqFtPerSqYd = 9;
  static const double sqFtPerMarla = 225;
  static const double sqFtPerKanal = 4500;

  /// Dropdown value → display label (order = dropdown order).
  static const Map<String, String> units = {
    'marla': 'Marla',
    'kanal': 'Kanal',
    'sqft': 'Sq Ft',
    'sqyd': 'Sq Yard (gaz)',
  };

  /// Converts a value in [unit] to square feet.
  static double toSqFt(double value, String unit) => switch (unit) {
        'marla' => value * sqFtPerMarla,
        'kanal' => value * sqFtPerKanal,
        'sqyd' => value * sqFtPerSqYd,
        _ => value,
      };

  /// Converts square feet into the given unit (inverse of [toSqFt]) —
  /// used when the wizard's area dropdown switches and the typed number
  /// should keep representing the SAME physical plot.
  static double fromSqFt(double sqft, String unit) => switch (unit) {
        'marla' => sqft / sqFtPerMarla,
        'kanal' => sqft / sqFtPerKanal,
        'sqyd' => sqft / sqFtPerSqYd,
        _ => sqft,
      };

  /// 1125 → "1,125"
  static String withCommas(double v) => v.round().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => ',',
      );

  static String _dec(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  /// "1,125 sq ft · 125 sq yd (gaz) · 5 Marla" — switches to Kanal at
  /// 1 Kanal and above.
  static String formatArea(double sqft) {
    final marla = sqft / sqFtPerMarla;
    final imperial =
        marla >= 20 ? '${_dec(marla / 20)} Kanal' : '${_dec(marla)} Marla';
    return '${withCommas(sqft)} sq ft · ${_dec(sqft / sqFtPerSqYd)} sq yd '
        '(gaz) · $imperial';
  }

  /// "1,125 sq ft (5 Marla)" — compact form for header strips and summary
  /// rows.
  static String formatAreaShort(double sqft) {
    final marla = sqft / sqFtPerMarla;
    final imperial =
        marla >= 20 ? '${_dec(marla / 20)} Kanal' : '${_dec(marla)} Marla';
    return '${withCommas(sqft)} sq ft ($imperial)';
  }
}
