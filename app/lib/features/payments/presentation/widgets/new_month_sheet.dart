import 'package:flutter/material.dart';

import 'peso.dart';
import 'peso_input_formatter.dart';

/// Picks a month to start, and a rough total that sizes its clouds.
///
/// Months that already exist are disabled rather than rejected after the
/// fact: the period is unique per month, and a refusal from the store arrives
/// as an unhelpful error.
class NewMonthSheet extends StatefulWidget {
  const NewMonthSheet({
    required this.initialPeriod,
    required this.isTaken,
    required this.initialEstimateCentavos,
    required this.onSave,
    super.key,
  });

  static const Key previousYearKey = ValueKey('new-month-previous-year');
  static const Key nextYearKey = ValueKey('new-month-next-year');
  static const Key estimateKey = ValueKey('new-month-estimate');

  final DateTime initialPeriod;

  /// Called with the first of a month.
  final bool Function(DateTime period) isTaken;

  final int? initialEstimateCentavos;

  /// Resolves to whether the month was created.
  final Future<bool> Function(DateTime period, int? expectedTotalCentavos)
      onSave;

  @override
  State<NewMonthSheet> createState() => _NewMonthSheetState();
}

class _NewMonthSheetState extends State<NewMonthSheet> {
  static const List<String> _names = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  late int _year;
  int? _month;
  late final TextEditingController _estimate;
  bool _saving = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _year = widget.initialPeriod.year;
    final month = widget.initialPeriod.month;
    _month = _taken(month) ? null : month;

    final estimate = widget.initialEstimateCentavos;
    _estimate = TextEditingController(
      text: estimate == null ? '' : formatPeso(estimate).substring(1),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _estimate.dispose();
    super.dispose();
  }

  bool _taken(int month) => widget.isTaken(DateTime(_year, month));

  void _changeYear(int delta) => setState(() {
        _year += delta;
        if (_month != null && _taken(_month!)) _month = null;
      });

  bool get _estimateBlank => _estimate.text.trim().isEmpty;
  bool get _estimateValid =>
      _estimateBlank || parsePesoToCentavos(_estimate.text) != null;
  bool get _canSave => !_saving && _month != null && _estimateValid;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    final ok = await widget.onSave(
      DateTime(_year, _month!),
      _estimateBlank ? null : parsePesoToCentavos(_estimate.text),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _failed = !ok;
    });
    if (ok) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
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
            'New month',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: NewMonthSheet.previousYearKey,
                tooltip: 'Previous year',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeYear(-1),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  '$_year',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                key: NewMonthSheet.nextYearKey,
                tooltip: 'Next year',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeYear(1),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var m = 1; m <= 12; m++)
                ChoiceChip(
                  label: Text(_names[m - 1]),
                  selected: _month == m,
                  showCheckmark: false,
                  onSelected: _taken(m)
                      ? null
                      : (_) => setState(() => _month = m),
                ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            key: NewMonthSheet.estimateKey,
            controller: _estimate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [PesoInputFormatter()],
            decoration: InputDecoration(
              labelText: 'Roughly how much this month?',
              prefixText: '₱ ',
              helperText: 'Sets how big each cloud is for this month.',
              errorText: _estimateValid ? null : 'Enter an amount like 45,000',
            ),
          ),
          if (_failed)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                "Couldn't create that month. Check your connection and try again.",
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
                : const Text('Create month'),
          ),
        ],
      ),
    );
  }
}
