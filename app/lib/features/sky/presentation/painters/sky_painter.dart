import 'package:flutter/material.dart';

import '../controllers/sky_controller.dart';
import 'cloud_path.dart';
import 'cloud_pose.dart';
import 'sky_palette.dart';
import 'sun_shape.dart';

class SkyPainter extends CustomPainter {
  SkyPainter(this.sky, {this.topInset = 0}) : super(repaint: sky);

  final SkyController sky;

  /// The notch or status bar height. Clouds are laid out below it.
  final double topInset;

  static final Path _cloud = buildCloudPath();
  static final Paint _paint = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    // Clouds are authored ~100 units wide; normalise to the sky's width so the
    // layout holds on any screen.
    final unit = size.width / 320;
    final stage = skyStage(size, topInset: topInset);
    final cloud = paletteFor(sky.gloom).cloud;

    for (final s in sky.sprites) {
      final pose = poseOf(s, time: sky.time);
      if (pose.alpha <= 0.01) continue;

      _paint.color = cloud.withValues(alpha: pose.alpha);

      final at = stagePoint(stage, pose.center);
      canvas.save();
      canvas.translate(at.dx, at.dy + pose.dy * unit);
      // Non-uniform on purpose: the squash is the anticipation beat. This is
      // also why drawAtlas is the wrong optimisation here — RSTransform only
      // carries uniform scale and would flatten it away.
      canvas.scale(
        sky.scale * pose.sx * unit,
        sky.scale * pose.sy * unit,
      );
      canvas.drawPath(_cloud, _paint);
      canvas.restore();
    }

    for (final p in sky.puffs) {
      final k = p.progress;
      final alpha = (1 - k) * (1 - k) * 0.9;
      if (alpha <= 0.01) continue;
      _paint.color = cloud.withValues(alpha: alpha);
      canvas.drawCircle(
        stagePoint(stage, p.position),
        p.radius * (1 + 0.8 * k) * sky.scale * unit,
        _paint,
      );
    }
  }

  // Passing the controller as `repaint:` subscribes this painter directly to
  // it, so notifyListeners() repaints without the widget tree rebuilding at
  // all. This method only governs the case where the widget itself is rebuilt
  // for some unrelated reason.
  @override
  bool shouldRepaint(SkyPainter oldDelegate) =>
      oldDelegate.sky != sky || oldDelegate.topInset != topInset;
}
