import 'package:flutter/material.dart';

/// One bump on top of a [CloudCard].
class CardPuff {
  const CardPuff(this.x, this.lift, this.radius);

  /// Centre, measured in from the edge the puffs gather on.
  final double x;

  /// How far the centre sits below the top of the card's body.
  final double lift;

  final double radius;
}

/// A rounded card with puffs rising off its top edge, so everything in the
/// list reads as a cloud. How big the puffs are and how heavy the fill is sets
/// how much a card stands out.
class CloudCard extends StatelessWidget {
  const CloudCard({
    required this.fill,
    required this.puffs,
    required this.rise,
    required this.child,
    this.radius = 16,
    this.elevation = 0,
    this.puffsOnRight = false,
    super.key,
  });

  final Color fill;
  final List<CardPuff> puffs;

  /// Room above the body for the puffs. [child] starts below it.
  final double rise;
  final double radius;
  final double elevation;
  final bool puffsOnRight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CloudCardPainter(this),
      child: Padding(padding: EdgeInsets.only(top: rise), child: child),
    );
  }
}

/// Squashes a little under a finger, like the add button, and calls [onTap]
/// on release.
class Squish extends StatefulWidget {
  const Squish({required this.onTap, required this.child, super.key});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<Squish> createState() => _SquishState();
}

class _SquishState extends State<Squish> {
  bool _down = false;

  void _set(bool down) => setState(() => _down = down);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) {
          _set(false);
          widget.onTap();
        },
        onTapCancel: () => _set(false),
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

class _CloudCardPainter extends CustomPainter {
  const _CloudCardPainter(this.card);

  final CloudCard card;

  @override
  void paint(Canvas canvas, Size size) {
    final top = card.rise;
    // Every sub-path winds the same way, so the fill unions them.
    final path = Path();
    for (final p in card.puffs) {
      final x = card.puffsOnRight ? size.width - p.x : p.x;
      path.addOval(
        Rect.fromCircle(center: Offset(x, top + p.lift), radius: p.radius),
      );
    }
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, size.width, size.height - top),
        Radius.circular(card.radius),
      ),
    );

    if (card.elevation > 0) {
      canvas.drawShadow(path, const Color(0xFF203040), card.elevation, false);
    }
    canvas.drawPath(path, Paint()..color = card.fill);
  }

  @override
  bool shouldRepaint(_CloudCardPainter oldDelegate) {
    final a = oldDelegate.card;
    final b = card;
    return a.fill != b.fill ||
        a.puffs != b.puffs ||
        a.rise != b.rise ||
        a.radius != b.radius ||
        a.elevation != b.elevation ||
        a.puffsOnRight != b.puffsOnRight;
  }
}
