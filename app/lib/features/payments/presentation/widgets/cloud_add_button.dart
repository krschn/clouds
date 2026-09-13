import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../sky/presentation/painters/cloud_path.dart';

/// Add-bill button shaped like the clouds it makes.
///
/// It bobs while idle, squashes under a press and springs back on release,
/// and recoils each time [recoil] notifies — once per cloud it launches.
///
/// With a [label] it carries that word instead of the "+", for the other
/// cloud buttons on the screen.
class CloudAddButton extends StatefulWidget {
  const CloudAddButton({
    required this.onPressed,
    this.recoil,
    this.size = const Size(84, 58),
    this.semanticLabel = 'Add bill',
    this.label,
    this.bob = true,
    super.key,
  });

  final VoidCallback onPressed;
  final Listenable? recoil;
  final Size size;
  final String semanticLabel;
  final String? label;

  /// Idle bobbing. Off for a cloud that should sit still, so only one thing
  /// on the screen is ever drifting for attention.
  final bool bob;

  @override
  State<CloudAddButton> createState() => _CloudAddButtonState();
}

class _CloudAddButtonState extends State<CloudAddButton>
    with TickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 520),
  );

  // elasticIn on the way back overshoots past rest, so letting go reads as a
  // spring rather than a fade.
  late final Animation<double> _squash = CurvedAnimation(
    parent: _press,
    curve: Curves.easeOut,
    reverseCurve: Curves.elasticIn,
  );

  late final AnimationController _kick = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  @override
  void initState() {
    super.initState();
    if (widget.bob) _bob.repeat();
    widget.recoil?.addListener(_onRecoil);
  }

  @override
  void didUpdateWidget(CloudAddButton old) {
    super.didUpdateWidget(old);
    if (old.recoil != widget.recoil) {
      old.recoil?.removeListener(_onRecoil);
      widget.recoil?.addListener(_onRecoil);
    }
  }

  void _onRecoil() => _kick.forward(from: 0);

  @override
  void dispose() {
    widget.recoil?.removeListener(_onRecoil);
    _bob.dispose();
    _press.dispose();
    _kick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press.forward(),
        onTapUp: (_) {
          _press.reverse();
          widget.onPressed();
        },
        onTapCancel: () => _press.reverse(),
        child: AnimatedBuilder(
          animation: Listenable.merge([_bob, _press, _kick]),
          builder: (context, child) {
            final bob = math.sin(_bob.value * 2 * math.pi) * 3;
            final p = _squash.value;
            final k = _kick.value;
            final recoil = math.sin(math.pi * k) * (1 - k);
            return Transform.translate(
              offset: Offset(0, bob + 4 * recoil),
              child: Transform.scale(
                scaleX: (1 + 0.12 * p) * (1 + 0.06 * recoil),
                scaleY: (1 - 0.14 * p) * (1 - 0.08 * recoil),
                alignment: Alignment.bottomCenter,
                child: child,
              ),
            );
          },
          child: CustomPaint(
            size: widget.size,
            painter: _CloudButtonPainter(plus: widget.label == null),
            child: widget.label == null
                ? null
                : SizedBox.fromSize(
                    size: widget.size,
                    child: Align(
                      // The cloud's body sits low, under its puffs.
                      alignment: const Alignment(0.04, 0.34),
                      child: Text(
                        widget.label!,
                        style: TextStyle(
                          fontSize: widget.size.height * 0.3,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0C447C),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _CloudButtonPainter extends CustomPainter {
  const _CloudButtonPainter({required this.plus});

  final bool plus;

  static final Path _cloud = buildCloudPath();

  @override
  void paint(Canvas canvas, Size size) {
    // The path spans roughly 88 x 42 authored units around the origin.
    final s = size.width / 96;
    final cx = size.width / 2;
    final cy = size.height / 2 + 1;
    final path = _cloud.transform(
      Float64List.fromList([
        s, 0, 0, 0, //
        0, s, 0, 0, //
        0, 0, 1, 0, //
        cx, cy, 0, 1, //
      ]),
    );

    canvas.drawShadow(path, const Color(0xFF203040), 6, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
    if (!plus) return;

    // Sized off the cloud so the "+" keeps its weight on the big empty-state
    // cloud as well as the small edge button.
    final pen = Paint()
      ..color = const Color(0xFF0C447C)
      ..strokeWidth = 3.7 * s
      ..strokeCap = StrokeCap.round;
    final center = Offset(cx + 2 * s, cy + 3 * s);
    final arm = 9.2 * s;
    canvas.drawLine(center - Offset(arm, 0), center + Offset(arm, 0), pen);
    canvas.drawLine(center - Offset(0, arm), center + Offset(0, arm), pen);
  }

  @override
  bool shouldRepaint(_CloudButtonPainter oldDelegate) =>
      oldDelegate.plus != plus;
}
