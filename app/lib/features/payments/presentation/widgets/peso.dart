/// The largest amount the server's int column can hold.
const int _maxCentavos = 2147483647;

final RegExp _pesoPattern = RegExp(r'^(\d*)(?:\.(\d{0,2}))?$');

/// Reads what someone typed as a peso amount and returns integer centavos, or
/// null if it is not a positive amount the server can store.
///
/// Parsed as text, digit by digit, so the value never passes through a double.
/// Commas and the peso sign are ignored; more than two decimals is rejected
/// rather than rounded, because silently rounding someone's bill is worse than
/// asking them to fix it.
int? parsePesoToCentavos(String input) {
  final cleaned = input.replaceAll('₱', '').replaceAll(',', '').trim();
  final match = _pesoPattern.firstMatch(cleaned);
  if (match == null) return null;

  final whole = match[1]!;
  final fraction = match[2] ?? '';
  if (whole.isEmpty && fraction.isEmpty) return null;
  // Past 12 digits it is over the cap anyway, and on web a longer run of
  // digits would not survive int.parse exactly.
  if (whole.length > 12) return null;

  final centavos = int.parse(whole.isEmpty ? '0' : whole) * 100 +
      int.parse(fraction.padRight(2, '0'));
  if (centavos < 1 || centavos > _maxCentavos) return null;
  return centavos;
}

/// Formats integer centavos for display. Kept in one place so no widget is
/// ever tempted to do peso math in a double.
String formatPeso(int centavos) {
  final pesos = centavos ~/ 100;
  final rem = centavos % 100;
  final whole = pesos.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
      );
  return rem == 0
      ? '\u20B1$whole'
      : '\u20B1$whole.${rem.toString().padLeft(2, '0')}';
}
