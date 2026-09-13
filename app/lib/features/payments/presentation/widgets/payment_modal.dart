import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../../sky/presentation/painters/cloud_path.dart';
import '../../domain/entities/payment.dart';
import 'cloud_words.dart';
import 'peso.dart';

/// Clear a bill by pushing its cloud up off the sun.
///
/// A hold only asks you to wait. Here the cloud follows the finger against a
/// pull that stiffens the further it goes, the sun it was covering shows
/// through and brightens, a detent clicks where letting go will clear, and on
/// release the cloud flies off into the sky before the sheet gets out of the
/// way — so the bursts up there are the last thing that happens, not hidden
/// behind a closing sheet.
class PaymentModal extends StatefulWidget {
  const PaymentModal({
    required this.payment,
    required this.cloudsRemoved,
    required this.onCleared,
    this.onProgress,
    super.key,
  });

  final Payment payment;
  final int cloudsRemoved;
  final VoidCallback onCleared;

  /// 0 → 1 as the cloud is pushed toward the detent, and back down if it
  /// springs back. Lets the sky make the clouds that are about to go tremble.
  final ValueChanged<double>? onProgress;

  /// The cloud you push, for tests.
  static const Key cloudKey = Key('payment-modal-cloud');

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal>
    with TickerProviderStateMixin {
  /// Finger travel, in logical pixels, past which letting go clears.
  static const double _detent = 120;

  /// A flick this fast clears from a shorter push.
  static const double _flickVelocity = 900;

  /// The cloud never visibly moves further than this while held: the pull
  /// stiffens toward it, so the last stretch to the detent costs the most.
  static const double _maxLift = 90;

  /// The stage is taller than the resting cloud, so a pushed cloud rises into
  /// open space instead of over the bill's name. The headroom above the cloud
  /// (_restY less half its height) covers the lift at the detent; only a hard
  /// pull past it nears [_maxLift].
  static const double _stageHeight = 200;
  static const double _restY = 132;

  static const Size _cloudSize = Size(230, 110);
  static const Size _sunSize = Size(200, 176);
  static const Color _navy = Color(0xFF0C447C);
  static const Color _muted = Color(0xFF5F6E80);

  /// Finger travel upward, driven by the finger and then by the spring back.
  late final AnimationController _drag =
      AnimationController.unbounded(vsync: this)..addListener(_onDrag);

  /// 0 → 1 as the released cloud flies away.
  late final AnimationController _fly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  /// The idle peek that shows a sliver of sun, until the first touch.
  late final AnimationController _nudge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  bool _dragging = false;
  bool _armed = false;
  bool _done = false;
  bool _delivered = false;

  /// Quarter marks already passed on this push, for the rising haptic ticks.
  int _quarters = 0;

  double get _progress => (_drag.value / _detent).clamp(0.0, 1.0);

  void _onDrag() {
    // Once committed, nothing the drag does matters any more.
    if (_done) return;
    widget.onProgress?.call(_progress);

    final quarters = (_progress * 4).floor().clamp(0, 3);
    if (quarters > _quarters && _dragging) {
      // Each tick harder than the last, so the push builds toward the detent.
      switch (quarters) {
        case 1:
          HapticFeedback.selectionClick();
        case 2:
          HapticFeedback.lightImpact();
        case 3:
          HapticFeedback.mediumImpact();
      }
    }
    _quarters = quarters;

    final armed = _drag.value >= _detent;
    if (armed != _armed) {
      _armed = armed;
      // The detent: a firm click going over, a soft one coming back.
      if (_dragging) {
        armed ? HapticFeedback.heavyImpact() : HapticFeedback.selectionClick();
      }
    }
  }

  void _start(DragStartDetails _) {
    if (_done) return;
    _nudge
      ..stop()
      ..value = 0;
    _drag.stop();
    _dragging = true;
  }

  void _update(DragUpdateDetails d) {
    if (_done) return;
    // Upward is positive. A little give downward, no more.
    _drag.value = math.max(-24, _drag.value - d.delta.dy);
  }

  void _end(DragEndDetails d) {
    if (_done) return;
    _dragging = false;
    final upward = -(d.primaryVelocity ?? 0);
    final flicked = upward > _flickVelocity && _drag.value > _detent * 0.35;
    if (_drag.value >= _detent || flicked) {
      _commit();
    } else {
      _springBack(upward);
    }
  }

  void _cancel() {
    if (_done) return;
    _dragging = false;
    _springBack(0);
  }

  void _springBack(double velocity) {
    // Underdamped, so it settles with a small bounce rather than sliding home.
    _drag.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 260, damping: 17),
        _drag.value,
        0,
        velocity,
      ),
    );
  }

  void _commit() {
    if (_done) return;
    // Full tension for the flight, however far the flick actually got.
    widget.onProgress?.call(1);
    _done = true;
    _dragging = false;
    _drag.stop();
    _nudge.stop();
    HapticFeedback.heavyImpact();
    _fly.forward().then((_) => _deliver());
  }

  void _deliver() {
    if (_delivered || !mounted) return;
    _delivered = true;
    widget.onCleared();
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    if (!_done) {
      // Dismissed mid-push: calm the clouds back down. Deferred like the
      // clear below: dispose runs while the tree is locked, and the sky
      // notifies widgets that would have to rebuild.
      final calm = widget.onProgress;
      if (calm != null) scheduleMicrotask(() => calm(0));
    } else if (!_delivered) {
      // Dismissed mid-flight: the clear was already decided. Delivered after
      // this frame, so the controller does not notify while the tree unmounts.
      _delivered = true;
      scheduleMicrotask(widget.onCleared);
    }
    _drag.dispose();
    _fly.dispose();
    _nudge.dispose();
    super.dispose();
  }

  double _lift(double raw) =>
      raw >= 0 ? _maxLift * (1 - math.exp(-raw / _maxLift)) : raw * 0.3;

  @override
  Widget build(BuildContext context) {
    final label = widget.payment.label;
    final amount = formatPeso(widget.payment.amountCentavos);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            'Clears ${cloudPhrase(widget.cloudsRemoved)}',
            style: const TextStyle(fontSize: 13, color: _muted),
          ),
          Semantics(
            button: true,
            label: 'Clear $label, $amount',
            hint: 'Swipe up, or double tap',
            onTap: _commit,
            excludeSemantics: true,
            child: GestureDetector(
              key: PaymentModal.cloudKey,
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: _start,
              onVerticalDragUpdate: _update,
              onVerticalDragEnd: _end,
              onVerticalDragCancel: _cancel,
              child: AnimatedBuilder(
                animation: Listenable.merge([_drag, _fly, _nudge]),
                builder: (context, _) => _stage(amount),
              ),
            ),
          ),
          _hint(),
        ],
      ),
    );
  }

  Widget _stage(String amount) {
    final p = _progress;
    final f = Curves.easeIn.transform(_fly.value);
    final t = _nudge.value;
    // A quick peek at the start of each cycle, then rest.
    final peek = math.sin(math.pi * math.min(1, t / 0.28)) * 9;
    final lift = _lift(_drag.value) + peek + f * 560;

    return SizedBox(
      height: _stageHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: _restY - _sunSize.height / 2,
            height: _sunSize.height,
            child: Center(
              child: CustomPaint(
                size: _sunSize,
                painter: _SunPainter(reveal: p, bloom: _fly.value),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: _restY - _cloudSize.height / 2,
            height: _cloudSize.height,
            child: Center(child: _cloud(amount, p, f, lift)),
          ),
        ],
      ),
    );
  }

  Widget _cloud(String amount, double p, double f, double lift) {
    return Transform.translate(
      offset: Offset(0, -lift),
      child: Transform.scale(
        // Stretches as it is pulled, shrinks as it leaves.
        scaleX: (1 - 0.03 * p) * (1 - 0.35 * f),
        scaleY: (1 + 0.05 * p) * (1 - 0.35 * f),
        child: Opacity(
          opacity: 1 - 0.7 * f,
          child: CustomPaint(
            size: _cloudSize,
            painter: _PaymentCloudPainter(elevation: 4 + 10 * p),
            child: SizedBox.fromSize(
              size: _cloudSize,
              child: Align(
                alignment: const Alignment(0.04, 0.32),
                child: Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hint() {
    return AnimatedBuilder(
      animation: Listenable.merge([_drag, _fly, _nudge]),
      builder: (context, _) {
        final ready = _armed || _done;
        final bob = math.sin(math.pi * math.min(1, _nudge.value / 0.28)) * 3;
        return Opacity(
          opacity: 1 - _fly.value,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.translate(
                offset: Offset(0, -bob),
                child: Icon(
                  ready ? Icons.wb_sunny_rounded : Icons.keyboard_arrow_up,
                  size: 20,
                  color: ready ? const Color(0xFFEF9F27) : _muted,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                ready ? 'Let go to clear' : 'Swipe up to clear',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: ready ? _navy : _muted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The bill's cloud: the sky's cloud shape, big enough to carry the amount.
class _PaymentCloudPainter extends CustomPainter {
  const _PaymentCloudPainter({required this.elevation});

  final double elevation;

  static final Path _cloud = buildCloudPath();

  @override
  void paint(Canvas canvas, Size size) {
    // The path spans roughly 88 x 42 authored units around the origin.
    final s = size.width / 96;
    final path = _cloud.transform(
      Float64List.fromList([
        s, 0, 0, 0, //
        0, s, 0, 0, //
        0, 0, 1, 0, //
        size.width / 2, size.height / 2 - 4, 0, 1, //
      ]),
    );
    canvas.drawShadow(path, const Color(0xFF203040), elevation, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PaymentCloudPainter oldDelegate) =>
      oldDelegate.elevation != elevation;
}

/// The sun behind the bill. Brightens and turns as the cloud is pushed off
/// it, and blooms when the cloud is let go.
class _SunPainter extends CustomPainter {
  const _SunPainter({required this.reveal, required this.bloom});

  final double reveal;
  final double bloom;

  @override
  void paint(Canvas canvas, Size size) {
    // Tucked a little high, so no ray pokes out under the resting cloud.
    final c = size.center(const Offset(0, -6));
    final grow = 1 + 0.12 * reveal + 0.3 * Curves.easeOut.transform(bloom);
    final r = 30 * grow;

    canvas.drawCircle(
      c,
      r * 2,
      Paint()
        ..color = const Color(0xFFFFE2A6)
            // No halo round the resting cloud: the glow is the push's reward.
            .withValues(alpha: (0.8 * reveal + 0.5 * bloom).clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    final ray = Paint()
      ..color = const Color(0xFFFAC775)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final spin = reveal * 0.7 + bloom * 1.4;
    const rays = 10;
    for (var i = 0; i < rays; i++) {
      final a = spin + i * 2 * math.pi / rays;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * (r + 7), c + dir * (r + 7 + 8 * grow), ray);
    }

    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFEF9F27));
  }

  @override
  bool shouldRepaint(_SunPainter oldDelegate) =>
      oldDelegate.reveal != reveal || oldDelegate.bloom != bloom;
}
