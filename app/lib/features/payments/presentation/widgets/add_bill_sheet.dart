import 'package:flutter/material.dart';

import '../../../sky/domain/entities/cloud_rule.dart';
import 'peso.dart';

/// Name and amount for a new bill.
///
/// The preview runs the month's own frozen rule against the balance, so
/// "Adds 3 clouds" is exactly what the sky does when it saves — not
/// amount / denominator, which is wrong whenever the last cloud is part-used.
class AddBillSheet extends StatefulWidget {
  const AddBillSheet({
    required this.rule,
    required this.outstandingCentavos,
    required this.onSave,
    super.key,
  });

  static const Key labelKey = ValueKey('add-bill-label');
  static const Key amountKey = ValueKey('add-bill-amount');

  final CloudRule rule;
  final int outstandingCentavos;

  /// Resolves to whether the bill was saved.
  final Future<bool> Function(String label, int amountCentavos) onSave;

  @override
  State<AddBillSheet> createState() => _AddBillSheetState();
}

class _AddBillSheetState extends State<AddBillSheet> {
  final TextEditingController _label = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  bool _saving = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _label.addListener(_changed);
    _amount.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    super.dispose();
  }

  int? get _centavos => parsePesoToCentavos(_amount.text);
  bool get _canSave =>
      !_saving && _label.text.trim().isNotEmpty && _centavos != null;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    final ok = await widget.onSave(_label.text.trim(), _centavos!);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _failed = !ok;
    });
    if (ok) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final centavos = _centavos;
    final added = centavos == null
        ? null
        : widget.rule.cloudsFor(widget.outstandingCentavos + centavos) -
            widget.rule.cloudsFor(widget.outstandingCentavos);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        22,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'New bill',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          TextField(
            key: AddBillSheet.labelKey,
            controller: _label,
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Name',
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: AddBillSheet.amountKey,
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (_canSave) _save();
            },
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₱ ',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 20,
            child: added == null
                ? null
                : Row(
                    children: [
                      const Icon(
                        Icons.cloud,
                        size: 18,
                        color: Color(0xFF9FB3C6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _preview(added),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF5F6E80),
                        ),
                      ),
                    ],
                  ),
          ),
          if (_failed)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                "Couldn't save that bill. Check your connection and try again.",
                style: TextStyle(fontSize: 13, color: Color(0xFFB3261E)),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _canSave ? _save : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFF0C447C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  static String _preview(int clouds) => switch (clouds) {
        0 => 'Fits in the clouds already there',
        1 => 'Adds 1 cloud',
        _ => 'Adds $clouds clouds',
      };
}
