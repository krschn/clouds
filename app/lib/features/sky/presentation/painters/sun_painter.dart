import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/sky_controller.dart';
import 'sky_palette.dart';
import 'sun_shape.dart';

/// Everything behind the clouds: the sky itself, the sun's warm glow, the
/// all-clear rings, and the flame-ringed sun.
///
/// Subscribed to the controller like SkyPainter, so the sun's pulse and the
/// sky's colour animate without rebuilding any widgets.
class SunPainter extends CustomPainter {
  SunPainter(this.sky, {this.topInset = 0}) : super(repaint: sky);

  final SkyController sky;

  /// The notch or status bar height. The sky's colour fills behind it; the
  /// sun is laid out below it.
  final double topInset;

  /// The flames at a disc radius of 1, built once. Each frame scales and
  /// rotates this rather than rebuilding it.
  static final Path _flames = buildSunFlames(radius: 1);

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

    final sun = sunLayout(size, topInset: topInset);
    final c = sun.center;

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
          sun.radius * 1.5 + spread * size.longestSide * 0.9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.shortestSide * 0.05 * (1 - k)
            ..color = Colors.white.withValues(alpha: 0.55 * (1 - k)),
        );
      }
    }

    final pulse = sky.sunPulse.clamp(-0.6, sunPulseMax);
    // Every factor here is bounded by maxSunSwell, which is what sunLayout
    // sized the sun against. Grow it past that and the flames reach the notch.
    final r = sun.radius *
        (1 + sunClaritySwell * clarity) *
        (1 + sunPulseSwell * pulse) *
        (1 + sunBloomSwell * bloom);

    // One tongue's turn over the finale. The ring repeats every tongue, so the
    // end pose matches the start and nothing snaps afterwards.
    final spin = Curves.easeInOutCubic.transform(f) * 2 * math.pi / sunTongues;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(spin);
    canvas.scale(r);
    canvas.drawPath(
      _flames,
      Paint()
        ..isAntiAlias = true
        // Flames fade back in a storm more than the disc does, so a heavy
        // month reads as a sun smothered rather than just a darker one.
        ..color = palette.sunCore.withValues(alpha: 0.55 + 0.45 * clarity),
    );
    canvas.restore();

    canvas.drawCircle(c, r, Paint()..color = palette.sunCore);
  }

  @override
  bool shouldRepaint(SunPainter oldDelegate) =>
      oldDelegate.sky != sky || oldDelegate.topInset != topInset;
}
