import 'package:flutter/services.dart';

/// Keeps a money field to what parsePesoToCentavos can read: digits and
/// commas, at most one decimal point, and at most two places after it.
///
/// Characters that can never belong are dropped, so a pasted "₱1,500.00"
/// still lands as an amount. An edit that would add a second point or a third
/// decimal place is refused outright, leaving the field as it was — silently
/// rounding someone's bill is worse than not taking the keystroke.
class PesoInputFormatter extends TextInputFormatter {
  const PesoInputFormatter();

  static final RegExp _notAmount = RegExp(r'[^0-9.,]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = newValue.text.replaceAll(_notAmount, '');

    final point = cleaned.indexOf('.');
    if (point != -1) {
      final decimals = cleaned.substring(point + 1);
      if (decimals.contains('.') ||
          decimals.contains(',') ||
          decimals.length > 2) {
        return oldValue;
      }
    }

    if (cleaned == newValue.text) return newValue;

    // Keep the caret where the typing was, less whatever got dropped before
    // it.
    final caret = newValue.selection.baseOffset;
    final offset = caret < 0
        ? cleaned.length
        : newValue.text
            .substring(0, caret.clamp(0, newValue.text.length))
            .replaceAll(_notAmount, '')
            .length;
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
