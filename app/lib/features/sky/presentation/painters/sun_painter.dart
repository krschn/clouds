import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/usecases/layout_clouds.dart';
import '../controllers/sky_controller.dart';
import 'sky_palette.dart';

/// Everything behind the clouds: the sky itself, the sun's warm glow, the
/// all-clear rings, and the sun.
///
/// Subscribed to the controller like SkyPainter, so the sun's pulse and the
/// sky's colour animate without rebuilding any widgets.
class SunPainter extends CustomPainter {
  SunPainter(this.sky) : super(repaint: sky);

  final SkyController sky;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = paletteFor(sky.gloom);
    final clarity = sky.clarity;
    final f = sky.finale;
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.skyTop, palette.skyBottom],
        ).createShader(rect),
    );

    final c = Offset(
      size.width * sunUnitCenter.dx,
      size.height * sunUnitCenter.dy,
    );

    // Rises and falls back over the celebration, overshooting early.
    final bloom = f > 0 && f < 1 ? math.sin(math.pi * f) * (1 - 0.4 * f) : 0.0;

    final glowRadius = size.longestSide * (0.55 + 0.25 * bloom);
    final glowAlpha =
        (palette.glow.a * (0.55 * clarity + 0.35 * bloom)).clamp(0.0, 1.0);
    canvas.drawCircle(
      c,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            palette.glow.withValues(alpha: glowAlpha),
            palette.glow.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: glowRadius)),
    );

    if (f > 0 && f < 1) {
      // Two rings, the second a beat behind, spreading past the sky's edge.
      for (final lag in const [0.0, 0.18]) {
        final k = ((f - lag) / (1 - lag)).clamp(0.0, 1.0);
        if (k <= 0 || k >= 1) continue;
        final spread = Curves.easeOutCubic.transform(k);
        canvas.drawCircle(
          c,
          size.shortestSide * 0.25 + spread * size.longestSide * 0.9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.shortestSide * 0.05 * (1 - k)
            ..color = Colors.white.withValues(alpha: 0.55 * (1 - k)),
        );
      }
    }

    final pulse = sky.sunPulse.clamp(-0.6, 1.5);
    final r = size.shortestSide *
        0.22 *
        (1 + 0.12 * clarity) *
        (1 + 0.06 * pulse) *
        (1 + 0.2 * bloom);

    final rays = Paint()
      ..color = palette.sunRay.withValues(alpha: 0.3 + 0.7 * clarity)
      ..strokeWidth = size.shortestSide * 0.025
      ..strokeCap = StrokeCap.round;

    // An eighth of a turn over the finale. Eight rays repeat every eighth, so
    // the end pose is identical to the start and nothing snaps afterwards.
    final spin = Curves.easeInOutCubic.transform(f) * math.pi / 4;
    final reach = size.shortestSide *
        0.06 *
        (0.6 + 0.4 * clarity) *
        (1 + 0.6 * bloom + 0.15 * math.max(0, pulse));
    for (var i = 0; i < 8; i++) {
      final a = spin + i * math.pi / 4;
      final inner = r * 1.35;
      final outer = inner + reach;
      canvas.drawLine(
        c + Offset(math.cos(a) * inner, math.sin(a) * inner),
        c + Offset(math.cos(a) * outer, math.sin(a) * outer),
        rays,
      );
    }

    canvas.drawCircle(
      c,
      r * 1.3,
      Paint()
        ..color = palette.sunCore.withValues(
          alpha: (0.16 * clarity + 0.2 * bloom).clamp(0.0, 1.0),
        ),
    );
    canvas.drawCircle(c, r, Paint()..color = palette.sunCore);
  }

  @override
  bool shouldRepaint(SunPainter oldDelegate) => oldDelegate.sky != sky;
}
