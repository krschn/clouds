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
