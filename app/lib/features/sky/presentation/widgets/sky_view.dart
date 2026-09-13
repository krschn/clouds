import 'package:flutter/material.dart';

import '../controllers/sky_controller.dart';
import '../painters/sky_painter.dart';
import '../painters/sun_painter.dart';

/// Sun plus clouds. The sky colour is derived from clarity so it can never
/// disagree with the cloud count.
class SkyView extends StatelessWidget {
  const SkyView({required this.controller, super.key});

  final SkyController controller;

  static const Color _heavy = Color(0xFFB5D4F4);
  static const Color _clear = Color(0xFFE6F1FB);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final clarity = controller.clarity;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOut,
          color: Color.lerp(_heavy, _clear, clarity),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: SunPainter(clarity: clarity)),
              // The boundary stops the payment list below from joining the
              // clouds' repaint every frame.
              RepaintBoundary(
                child: ClipRect(
                  child: CustomPaint(
                    painter: SkyPainter(
                      sprites: controller.sprites,
                      scale: controller.scale,
                      repaint: controller,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
