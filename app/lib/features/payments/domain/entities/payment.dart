class Payment {
  const Payment({
    required this.id,
    required this.label,
    required this.amountCentavos,
    required this.clearedAt,
    this.source = 'manual',
  });

  final String id;
  final String label;

  /// Integer centavos. See CloudRule for why this is never a double.
  final int amountCentavos;
  final DateTime? clearedAt;
  final String source;

  bool get isCleared => clearedAt != null;

  Payment copyWith({DateTime? clearedAt, bool clearCleared = false}) => Payment(
        id: id,
        label: label,
        amountCentavos: amountCentavos,
        clearedAt: clearCleared ? null : (clearedAt ?? this.clearedAt),
        source: source,
      );
}
