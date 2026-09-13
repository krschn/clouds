import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../domain/entities/cloud_rule.dart';
import '../../domain/entities/cloud_sprite.dart';
import '../../domain/usecases/layout_clouds.dart';

/// Drives every cloud in the sky from a SINGLE Ticker.
///
/// The tempting alternative — one AnimationController per cloud — gives you
/// forty independent clocks for a heavy month, forty widget elements
/// rebuilding each frame, and a stagger that visibly desyncs the moment a
/// frame runs long. One ticker, one painter, zero widget rebuilds.
class SkyController extends ChangeNotifier {
  SkyController({required TickerProvider vsync, required CloudRule rule})
      : _rule = rule {
    _ticker = vsync.createTicker(_onTick);
  }

  static const double exitSeconds = 0.78;
  static const double entrySeconds = 0.42;

  /// 70ms. Deliberately tighter than the drift variant's 130ms — the shorter
  /// stagger is what makes evaporate read as one mass dissolve rather than a
  /// procession. If you ever port the drift exit back, the stagger has to move
  /// with it or the two converge.
  static const double staggerSeconds = 0.07;

  late final Ticker _ticker;
  CloudRule _rule;
  final List<CloudSprite> _sprites = [];
  int _nextSlot = 0;
  double _scale = 1;
  Duration _last = Duration.zero;

  List<CloudSprite> get sprites => _sprites;
  double get scale => _scale;
  CloudRule get rule => _rule;

  /// 0 when the sky is full, 1 when it is clear. Drives ray opacity and the
  /// sun's scale, so brightness can never desync from the cloud count.
  double get clarity {
    final live = _sprites.where((s) => !s.exiting).length;
    if (_rule.maxClouds == 0) return 1;
    return 1 - math.min(1, live / _rule.maxClouds);
  }

  void updateRule(CloudRule rule) {
    _rule = rule;
    notifyListeners();
  }

  /// Reconcile the sky to [targetCount]. Additions pop in, removals evaporate
  /// nearest-the-sun first so the sun's face clears before the edges.
  void syncTo(int targetCount, {bool animate = true}) {
    final live = _sprites.where((s) => !s.exiting).toList();
    _scale = _rule.scaleFor(math.max(targetCount, live.length));

    if (targetCount > live.length) {
      _add(targetCount - live.length, animate: animate);
    } else if (targetCount < live.length) {
      _dismiss(live.length - targetCount, animate: animate);
    } else {
      notifyListeners();
    }
  }

  void _add(int count, {bool animate = true}) {
    for (var i = 0; i < count; i++) {
      _sprites.add(
        buildSprite(_nextSlot++, _rule.maxClouds, entry: animate ? 0 : 1),
      );
    }
    if (animate) _start();
    notifyListeners();
  }

  void _dismiss(int count, {bool animate = true}) {
    final leaving = _sprites.where((s) => !s.exiting).toList()
      ..sort((a, b) => a.distanceFromSun.compareTo(b.distanceFromSun));

    for (var i = 0; i < count && i < leaving.length; i++) {
      final s = leaving[i];
      s.exiting = true;
      s.delay = animate ? staggerSeconds * i : 0;
      if (!animate) s.t = 1;
    }

    if (animate) {
      _start();
    } else {
      _sprites.removeWhere((s) => s.finished);
      notifyListeners();
    }
  }

  void _start() {
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;

    var busy = false;

    for (final s in _sprites) {
      if (s.entry < 1) {
        s.entry = math.min(1, s.entry + dt / entrySeconds);
        if (s.entry < 1) busy = true;
      }
      if (!s.exiting) continue;
      if (s.delay > 0) {
        s.delay -= dt;
        busy = true;
        continue;
      }
      s.t = math.min(1, s.t + dt / exitSeconds);
      if (s.t < 1) busy = true;
    }

    _sprites.removeWhere((s) => s.finished);
    notifyListeners();

    if (!busy) {
      _ticker.stop();
      _last = Duration.zero;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
