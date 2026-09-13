import 'package:flutter/material.dart';

import '../../domain/entities/month.dart';

class MonthDrawer extends StatelessWidget {
  const MonthDrawer({
    required this.months,
    required this.currentId,
    required this.onSelect,
    super.key,
  });

  final List<Month> months;
  final String? currentId;
  final ValueChanged<Month> onSelect;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                'Month settings',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            // Past and future months reuse the same sun/clouds/list screen —
            // there is deliberately no separate historical view.
            for (final m in months)
              ListTile(
                selected: m.id == currentId,
                title: Text(_label(m.period), style: const TextStyle(fontSize: 14)),
                subtitle: Text(
                  m.cloudCount == 0
                      ? 'Clear'
                      : '${m.cloudCount} clouds',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  onSelect(m);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  static const List<String> _names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _label(DateTime d) => '${_names[d.month - 1]} ${d.year}';
}
