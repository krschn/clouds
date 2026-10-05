import 'package:flutter/material.dart';

import '../../../sky/presentation/painters/cloud_path.dart';
import '../../../sky/presentation/painters/sky_palette.dart';
import '../../domain/entities/month.dart';
import 'cloud_card.dart';
import 'peso.dart';

/// Every month as its own cloud, each with a little window onto that month's
/// sky, so a heavy month looks heavy before you open it.
class MonthDrawer extends StatelessWidget {
  const MonthDrawer({
    required this.months,
    required this.currentId,
    required this.onSelect,
    required this.onNewMonth,
    super.key,
  });

  final List<Month> months;
  final String? currentId;
  final ValueChanged<Month> onSelect;
  final VoidCallback onNewMonth;

  static const Color _navy = Color(0xFF0C447C);

  @override
  Widget build(BuildContext context) {
    // Newest first: the month you are most likely after sits at the top.
    final newestFirst = months.reversed.toList();

    return Drawer(
      width: 316,
      backgroundColor: const Color(0xFFF4F8FC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        // The clear-day sky, fading into the page colour.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFCFE6FA), Color(0xFFF4F8FC)],
            stops: [0, 0.45],
          ),
        ),
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(22, 18, 22, 6),
                child: Text(
                  'Months',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
              ),
              // Past and future months reuse the same sun/clouds/list screen —
              // there is deliberately no separate historical view.
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: newestFirst.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final m = newestFirst[i];
                    return _MonthCloud(
                      month: m,
                      label: _label(m.period),
                      selected: m.id == currentId,
                      puffsOnRight: i.isOdd,
                      onTap: () {
                        onSelect(m);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Squish(
                  onTap: () {
                    Navigator.of(context).pop();
                    onNewMonth();
                  },
                  // One cloud card that says what it does, like the months
                  // above it — not the home screen's "+" cloud, which adds
                  // bills.
                  child: const CloudCard(
                    fill: Color(0xFFDCEAF7),
                    puffs: _MonthCloud._puffs,
                    rise: 12,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: Center(
                        child: Text(
                          'Add month',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _navy,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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

/// One month: its sky, its name, what is left, and how much is already paid.
/// The month on screen is the navy cloud, matching the total.
class _MonthCloud extends StatelessWidget {
  const _MonthCloud({
    required this.month,
    required this.label,
    required this.selected,
    required this.puffsOnRight,
    required this.onTap,
  });

  final Month month;
  final String label;
  final bool selected;
  final bool puffsOnRight;
  final VoidCallback onTap;

  static const List<CardPuff> _puffs = [
    CardPuff(30, 10, 12),
    CardPuff(52, 8, 17),
    CardPuff(74, 9, 11),
  ];

  @override
  Widget build(BuildContext context) {
    final total = month.payments.fold<int>(0, (s, p) => s + p.amountCentavos);
    final owed = month.outstandingCentavos;
    final ink = selected ? Colors.white : const Color(0xFF1B2733);
    final soft = selected
        ? Colors.white.withValues(alpha: 0.75)
        : const Color(0xFF5F6B76);
    final status = total == 0
        ? 'No bills yet'
        : owed == 0
            ? 'All clear'
            : '${formatPeso(owed)} left';

    return Squish(
      onTap: onTap,
      child: CloudCard(
        fill: selected ? MonthDrawer._navy : Colors.white,
        puffs: _puffs,
        rise: 12,
        elevation: selected ? 3 : 1.2,
        puffsOnRight: puffsOnRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 14),
          child: Row(
            children: [
              _SkyWindow(month: month),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(status, style: TextStyle(fontSize: 13, color: soft)),
                    if (total > 0) ...[
                      const SizedBox(height: 8),
                      _PaidBar(
                        fraction: (total - owed) / total,
                        onDark: selected,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How much of the month is paid, by amount.
class _PaidBar extends StatelessWidget {
  const _PaidBar({required this.fraction, required this.onDark});

  final double fraction;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: onDark
                  ? Colors.white.withValues(alpha: 0.22)
                  : const Color(0xFFE3EAF1),
            ),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: ColoredBox(
                color: onDark
                    ? const Color(0xFF9FE1CB)
                    : const Color(0xFF0F6E56),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A thumbnail of the month's sky, in the same colours the big sky would use.
class _SkyWindow extends StatelessWidget {
  const _SkyWindow({required this.month});

  final Month month;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CustomPaint(
        size: const Size(48, 44),
        painter: _SkyWindowPainter(
          gloom: gloomFor(month.cloudCount, month.rule.maxClouds),
          cloudy: month.cloudCount > 0,
        ),
      ),
    );
  }
}

class _SkyWindowPainter extends CustomPainter {
  const _SkyWindowPainter({required this.gloom, required this.cloudy});

  final double gloom;
  final bool cloudy;

  static final Path _cloud = buildCloudPath();

  @override
  void paint(Canvas canvas, Size size) {
    final p = paletteFor(gloom);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.skyTop, p.skyBottom],
        ).createShader(rect),
    );
    canvas.drawCircle(
      Offset(size.width * 0.42, size.height * 0.42),
      size.height * 0.24,
      Paint()..color = p.sunCore,
    );
    if (!cloudy) return;

    final fill = Paint()..color = p.cloud;
    // A second cloud once the month is past half-gloomy.
    if (gloom > 0.45) {
      _drawCloud(canvas, Offset(size.width * 0.3, size.height * 0.8), 0.26, fill);
    }
    _drawCloud(canvas, Offset(size.width * 0.62, size.height * 0.66), 0.34, fill);
  }

  void _drawCloud(Canvas canvas, Offset at, double scale, Paint paint) {
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..scale(scale)
      ..drawPath(_cloud, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_SkyWindowPainter oldDelegate) =>
      oldDelegate.gloom != gloom || oldDelegate.cloudy != cloudy;
}
