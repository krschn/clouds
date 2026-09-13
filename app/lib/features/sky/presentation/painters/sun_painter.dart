import 'dart:math' as math;

import 'package:flutter/material.dart';

class SunPainter extends CustomPainter {
  const SunPainter({required this.clarity});

  /// 0 = fully obscured, 1 = clear sky.
  final double clarity;

  static const Color _core = Color(0xFFEF9F27);
  static const Color _ray = Color(0xFFFAC775);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.22 * (1 + 0.12 * clarity);

    final rays = Paint()
      ..color = _ray.withValues(alpha: 0.3 + 0.7 * clarity)
      ..strokeWidth = size.shortestSide * 0.025
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final inner = r * 1.35;
      final outer = inner + size.shortestSide * 0.06 * (0.6 + 0.4 * clarity);
      canvas.drawLine(
        c + Offset(math.cos(a) * inner, math.sin(a) * inner),
        c + Offset(math.cos(a) * outer, math.sin(a) * outer),
        rays,
      );
    }

    canvas.drawCircle(c, r, Paint()..color = _core);
  }

  @override
  bool shouldRepaint(SunPainter old) => old.clarity != clarity;
}
