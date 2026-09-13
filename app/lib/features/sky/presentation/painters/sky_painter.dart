import 'package:flutter/material.dart';

import '../../domain/entities/cloud_sprite.dart';
import 'cloud_path.dart';
import 'evaporate_curve.dart';

class SkyPainter extends CustomPainter {
  SkyPainter({
    required this.sprites,
    required this.scale,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final List<CloudSprite> sprites;
  final double scale;

  static final Path _cloud = buildCloudPath();
  static final Paint _paint = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    // Clouds are authored ~100 units wide; normalise to the sky's width so the
    // layout holds on any screen.
    final unit = size.width / 320;

    for (final s in sprites) {
      final exit = evaporateAt(s.t);
      final enter = entryAt(s.entry);
      final alpha = exit.alpha * enter.alpha;
      if (alpha <= 0.01) continue;

      _paint.color = Color.fromRGBO(255, 255, 255, alpha);

      canvas.save();
      canvas.translate(
        s.unitCenter.dx * size.width,
        s.unitCenter.dy * size.height + exit.dy * unit,
      );
      // Non-uniform on purpose: the 1.06x / 0.90x squash is the anticipation
      // beat. This is also why drawAtlas is the wrong optimisation here —
      // RSTransform only carries uniform scale and would flatten it away.
      canvas.scale(
        scale * exit.sx * enter.scale * unit,
        scale * exit.sy * enter.scale * unit,
      );
      canvas.drawPath(_cloud, _paint);
      canvas.restore();
    }
  }

  // false on purpose. Passing the controller as `repaint:` subscribes this
  // painter directly to it, so notifyListeners() repaints without the widget
  // tree rebuilding at all. This method only governs the case where the widget
  // itself is rebuilt for some unrelated reason.
  @override
  bool shouldRepaint(SkyPainter oldDelegate) => false;
}
