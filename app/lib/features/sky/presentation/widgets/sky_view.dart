import 'package:flutter/material.dart';

import '../controllers/sky_controller.dart';
import '../painters/sky_painter.dart';
import '../painters/sun_painter.dart';

/// Sky, sun and clouds. Both painters listen to the controller directly, so an
/// animation frame repaints them without rebuilding this widget.
class SkyView extends StatelessWidget {
  const SkyView({required this.controller, super.key});

  final SkyController controller;

  @override
  Widget build(BuildContext context) {
    // The boundary stops the payment list below from joining the sky's repaint
    // every frame.
    return RepaintBoundary(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: SunPainter(controller)),
            CustomPaint(painter: SkyPainter(controller)),
          ],
        ),
      ),
    );
  }
}
