import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../domain/entities/cloud_rule.dart';
import '../../domain/entities/cloud_sprite.dart';
import '../../domain/entities/puff.dart';
import '../../domain/usecases/group_clouds.dart';
import '../../domain/usecases/layout_clouds.dart';
import '../painters/evaporate_curve.dart';
import '../painters/sky_palette.dart';
import 'sky_haptics.dart';

/// Which clouds a shrink removes. When clearing reaches into a big cloud,
/// [split] is the big cloud that breaks and [pieces] is how many small clouds
/// fly out of it for the part still owed.
typedef _RemovalPlan = ({
  List<CloudSprite> leaving,
  CloudSprite? split,
  int pieces,
});

/// Drives every cloud, puff, sun pulse and colour in the sky from a SINGLE
/// Ticker.
///
/// The tempting alternative — one AnimationController per cloud — gives you
/// forty independent clocks for a heavy month, forty widget elements
/// rebuilding each frame, and a stagger that visibly desyncs the moment a
/// frame runs long. One ticker, painters subscribed to it, zero widget
/// rebuilds for the clouds themselves.
class SkyController extends ChangeNotifier {
  SkyController({
    required TickerProvider vsync,
    required CloudRule rule,
    SkyHaptics haptics = const PlatformSkyHaptics(),
  })  : _rule = rule,
        _haptics = haptics {
    _ticker = vsync.createTicker(_onTick);
  }

  static const double exitSeconds = 0.9;

  /// How long small clouds take to fly into a forming big cloud.
  static const double gatherSeconds = 0.45;

  /// 70ms. Tight enough that evaporate reads as one mass dissolve rather than
  /// a procession, loose enough that each burst gets its own haptic tap.
  static const double staggerSeconds = 0.07;

  static const double entryStaggerSeconds = 0.09;

  /// Launched clouds wait this long so the bill sheet is out of the way before
  /// they leave the button.
  static const double launchLeadSeconds = 0.3;

  static const double finaleSeconds = 1.6;

  static double entrySecondsFor(CloudEntry style) => switch (style) {
        CloudEntry.drop => 0.55,
        CloudEntry.launch => 0.85,
        CloudEntry.gather => 0.5,
        // Slower than the exit on purpose: a setback should not feel snappy.
        CloudEntry.condense => 1.2,
      };

  /// How quickly the colours chase the cloud count, per second.
  static const double _glideRate = 3.5;

  /// The sun's pulse is a damped spring; each burst is an impulse into it.
  static const double _pulseStiffness = 180;
  static const double _pulseDamping = 14;

  late final Ticker _ticker;
  CloudRule _rule;
  final SkyHaptics _haptics;
  final List<CloudSprite> _sprites = [];
  final List<Puff> _puffs = [];

  /// Slots evaporated most recently, so a rollback can re-form those exact
  /// clouds instead of growing new ones somewhere else.
  final List<int> _dismissedSlots = [];

  double _scale = 1;
  Duration _last = Duration.zero;
  double _time = 0;
  double _shown = 0;
  double _pulse = 0;
  double _pulseVelocity = 0;
  double _finale = 0;
  bool _finaleArmed = false;
  bool _finaleRunning = false;

  /// Where newly added clouds are thrown from, in unit sky coordinates. Set by
  /// the page that knows where the add button is; null means clouds drop in.
  Offset? launchFrom;

  /// Ticks once each time a cloud leaves the add button, so the button can
  /// recoil in step.
  final ValueNotifier<int> launches = ValueNotifier(0);

  List<CloudSprite> get sprites => _sprites;
  List<Puff> get puffs => _puffs;
  double get scale => _scale;
  CloudRule get rule => _rule;

  /// Seconds of animation so far. Drives the tremble.
  double get time => _time;

  /// 0 → 1 how stormy the screen is. Follows the clouds smoothly: each burst
  /// lightens it and each arrival darkens it, rather than jumping on the
  /// frame the count changes.
  double get gloom => gloomFor(_shown, _rule.maxClouds);

  /// 0 when the sky is full, 1 when it is clear. Drives the sun's size and
  /// rays. Shares [gloom]'s source, so brightness can never desync from it.
  double get clarity => 1 - math.min(1, _shown / _rule.maxClouds);

  /// The sun's spring displacement; positive is swollen.
  double get sunPulse => _pulse;

  /// 0 → 1 progress of the all-clear celebration. Stays at 1 once it has
  /// played, and returns to 0 when clouds come back or the month changes.
  double get finale => _finale;

  void updateRule(CloudRule rule) {
    _rule = rule;
    notifyListeners();
  }

  /// Reconcile the sky to [targetCount] clouds, drawn as big clouds of
  /// [cloudsPerBigCloud] plus small ones. Removals evaporate nearest-the-sun
  /// first so the sun's face clears before the edges.
  ///
  /// Additions arrive as [entry], defaulting to a launch from [launchFrom]
  /// when there is one. `animate: false` is for navigation: the sky is laid
  /// out afresh for the current rule, with no bursts, haptics or celebration.
  void syncTo(int targetCount, {bool animate = true, CloudEntry? entry}) {
    if (!animate) _settleInstantly();
    for (final s in _sprites) {
      s.tension = 0;
    }

    final from = _liveGroups();
    final to = cloudGroups(targetCount);
    _scale = _rule.scaleFor(math.max(paintedCount(from), paintedCount(to)));

    if (unitsIn(to) > unitsIn(from)) {
      _grow(
        from,
        to,
        animate: animate,
        style: entry ??
            (launchFrom == null ? CloudEntry.drop : CloudEntry.launch),
      );
    } else if (unitsIn(to) < unitsIn(from)) {
      _shrink(to);
    }

    if (animate) {
      _start();
    } else {
      _shown = _targetWeight();
    }
    notifyListeners();
  }

  /// Makes the clouds a pending clear of [count] would remove tremble with
  /// [amount] (0 → 1). They come from the same plan the clear uses, so the
  /// clouds that shake — including a big cloud about to split — are exactly
  /// the ones that then leave.
  void setTension(int count, double amount) {
    final live = unitsIn(_liveGroups());
    final shaking = count > 0
        ? _plan(cloudGroups(live - count)).leaving.toSet()
        : const <CloudSprite>{};
    for (final s in _sprites) {
      if (!s.exiting) s.tension = shaking.contains(s) ? amount : 0;
    }
    if (amount > 0) _start();
    notifyListeners();
  }

  /// Drops every sprite, so the caller rebuilds the sky from slot 0 under the
  /// current rule. A month's sky must not depend on what was shown before it:
  /// keeping old sprites would carry over another month's slots and capacity.
  void _settleInstantly() {
    _sprites.clear();
    _puffs.clear();
    _dismissedSlots.clear();
    _pulse = 0;
    _pulseVelocity = 0;
    _finale = 0;
    _finaleArmed = false;
    _finaleRunning = false;
  }

  CloudGroups _liveGroups() {
    var big = 0;
    var small = 0;
    for (final s in _sprites) {
      if (s.exiting) continue;
      if (s.units > 1) {
        big++;
      } else {
        small++;
      }
    }
    return (big: big, small: small);
  }

  void _grow(
    CloudGroups from,
    CloudGroups to, {
    required bool animate,
    required CloudEntry style,
  }) {
    _finale = 0;
    _finaleArmed = false;
    _finaleRunning = false;

    final taken = {
      for (final s in _sprites)
        if (!s.exiting) s.slot,
    };
    var bigs = to.big - from.big;
    var smalls = to.small - from.small;

    if (smalls < 0) {
      // Crossing a multiple of five: the loose small clouds fly together and
      // a big cloud swells up where they meet. Only reachable when animating,
      // since a non-animated sync starts from an empty sky.
      final loose = _sprites
          .where((s) => !s.exiting && s.units == 1)
          .toList()
        ..sort((a, b) => a.distanceFromSun.compareTo(b.distanceFromSun));
      taken.removeAll(loose.map((s) => s.slot));

      final big = _arrive(
        units: cloudsPerBigCloud,
        order: 0,
        style: CloudEntry.gather,
        taken: taken,
        animate: true,
        lead: gatherSeconds * 0.5,
      );
      for (final s in loose) {
        s
          ..exiting = true
          ..mergeInto = big.unitCenter;
      }
      bigs -= 1;
      smalls = to.small;
    }

    var order = 0;
    for (var i = 0; i < bigs; i++) {
      _arrive(
        units: cloudsPerBigCloud,
        order: order++,
        style: style,
        taken: taken,
        animate: animate,
      );
    }
    for (var i = 0; i < smalls; i++) {
      _arrive(
        units: 1,
        order: order++,
        style: style,
        taken: taken,
        animate: animate,
      );
    }
  }

  void _shrink(CloudGroups to) {
    final plan = _plan(to);
    final leaving = [...plan.leaving]
      ..sort((a, b) => a.distanceFromSun.compareTo(b.distanceFromSun));

    for (var i = 0; i < leaving.length; i++) {
      leaving[i]
        ..exiting = true
        ..delay = staggerSeconds * i;
      _dismissedSlots.add(leaving[i].slot);
    }

    final split = plan.split;
    if (split != null) {
      // The pieces appear on the split cloud's burst and fly to open spots.
      final taken = {
        for (final s in _sprites)
          if (!s.exiting) s.slot,
      };
      for (var i = 0; i < plan.pieces; i++) {
        _arrive(
          units: 1,
          order: i,
          style: CloudEntry.launch,
          origin: split.unitCenter,
          lead: split.delay + exitSeconds * evaporateBurstAt,
          taken: taken,
          animate: true,
        );
      }
    }

    if (unitsIn(to) == 0 && leaving.isNotEmpty) _finaleArmed = true;
  }

  /// Nearest-the-sun first within each size. A split only happens when the
  /// small clouds left over need to outnumber the ones there now, which means
  /// a big cloud has to break to make up the difference.
  _RemovalPlan _plan(CloudGroups to) {
    int byDistance(CloudSprite a, CloudSprite b) =>
        a.distanceFromSun.compareTo(b.distanceFromSun);
    final live = _sprites.where((s) => !s.exiting);
    final bigs = live.where((s) => s.units > 1).toList()..sort(byDistance);
    final smalls = live.where((s) => s.units == 1).toList()..sort(byDistance);

    if (to.small <= smalls.length) {
      return (
        leaving: [
          ...bigs.take(math.max(0, bigs.length - to.big)),
          ...smalls.take(smalls.length - to.small),
        ],
        split: null,
        pieces: 0,
      );
    }

    final split = bigs.first;
    return (
      leaving: [split, ...bigs.skip(1).take(bigs.length - to.big - 1)],
      split: split,
      pieces: to.small - smalls.length,
    );
  }

  CloudSprite _arrive({
    required int units,
    required int order,
    required CloudEntry style,
    required Set<int> taken,
    required bool animate,
    Offset? origin,
    double lead = 0,
  }) {
    final reused = style == CloudEntry.condense ? _takeDismissed(taken) : null;
    final slot = reused ?? _lowestFree(taken);
    taken.add(slot);
    // A re-forming cloud replaces its own fading ghost. Anything else leaves
    // a fading cloud to finish, even if a new one lands on its spot.
    if (reused != null) {
      _sprites.removeWhere((s) => s.exiting && s.slot == slot);
    }

    final fromButton = style == CloudEntry.launch && origin == null;
    final sprite = buildSprite(
      slot,
      _rule.maxClouds,
      entry: animate ? 0 : 1,
      entryStyle: style,
      origin: style == CloudEntry.launch ? (origin ?? launchFrom) : null,
      units: units,
    );
    if (animate) {
      sprite.entryDelay = lead +
          (fromButton ? launchLeadSeconds : 0) +
          entryStaggerSeconds * order;
    }
    _sprites.add(sprite);
    return sprite;
  }

  /// Slots count up from the sun outward, so the lowest free one is the gap
  /// nearest the sun. Filling from there covers the sun first and keeps slot
  /// numbers from creeping upward over a long session.
  static int _lowestFree(Set<int> taken) {
    var slot = 0;
    while (taken.contains(slot)) {
      slot++;
    }
    return slot;
  }

  int? _takeDismissed(Set<int> taken) {
    while (_dismissedSlots.isNotEmpty) {
      final slot = _dismissedSlots.removeLast();
      if (!taken.contains(slot)) return slot;
    }
    return null;
  }

  /// The cloud count the colours should show: arriving clouds count in
  /// proportion to how far they have come, a cloud stops counting the moment
  /// it bursts, and a gathering cloud stops once it has flown in.
  double _targetWeight() {
    var weight = 0.0;
    for (final s in _sprites) {
      if (s.exiting && (s.burst || (s.mergeInto != null && s.t >= 1))) {
        continue;
      }
      weight += s.units * s.entry;
    }
    return weight;
  }

  void _start() {
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    // Capped so a long stall (a backgrounded tab, a debugger pause) cannot
    // fling every animation to its end in one frame.
    final dt = _last == Duration.zero
        ? 1 / 60
        : math.min(1 / 20, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    _time += dt;

    var busy = false;

    for (final s in _sprites) {
      if (s.tension > 0) busy = true;

      if (s.entry < 1) {
        busy = true;
        if (s.entryDelay > 0) {
          s.entryDelay -= dt;
          if (s.entryDelay <= 0 &&
              s.entryStyle == CloudEntry.launch &&
              s.origin == launchFrom) {
            launches.value++;
          }
        } else {
          s.entry = math.min(1, s.entry + dt / entrySecondsFor(s.entryStyle));
          if (!s.landed && s.entry >= landingAt(s.entryStyle)) {
            s.landed = true;
            if (s.entryStyle != CloudEntry.condense) _haptics.land();
          }
        }
      }

      if (!s.exiting) continue;
      if (s.delay > 0) {
        s.delay -= dt;
        busy = true;
        continue;
      }
      final gathering = s.mergeInto != null;
      s.t = math.min(1, s.t + dt / (gathering ? gatherSeconds : exitSeconds));
      if (!gathering && !s.burst && s.t >= evaporateBurstAt) {
        s.burst = true;
        _burst(s);
      }
      if (s.t < 1) busy = true;
    }
    _sprites.removeWhere((s) => s.finished);

    // The celebration starts on the last burst rather than when the last
    // cloud has fully faded, so the payoff lands with the final pop.
    if (_finaleArmed && _sprites.every((s) => s.exiting && s.burst)) {
      _finaleArmed = false;
      _finaleRunning = true;
      _finale = 0;
      _pulseVelocity += 10;
      _haptics.finale();
    }
    if (_finaleRunning) {
      _finale = math.min(1, _finale + dt / finaleSeconds);
      if (_finale < 1) {
        busy = true;
      } else {
        _finaleRunning = false;
      }
    }

    final drag = math.exp(-3.2 * dt);
    for (final p in _puffs) {
      p
        ..age += dt
        ..position += p.velocity * dt
        ..velocity *= drag;
    }
    _puffs.removeWhere((p) => p.finished);
    if (_puffs.isNotEmpty) busy = true;

    final accel = -_pulseStiffness * _pulse - _pulseDamping * _pulseVelocity;
    _pulseVelocity += accel * dt;
    _pulse += _pulseVelocity * dt;
    if (_pulse.abs() > 1e-3 || _pulseVelocity.abs() > 1e-3) busy = true;

    final target = _targetWeight();
    _shown += (target - _shown) * (1 - math.exp(-_glideRate * dt));
    if ((target - _shown).abs() > 1e-3) busy = true;

    if (!busy) {
      _shown = target;
      _pulse = 0;
      _pulseVelocity = 0;
      _ticker.stop();
      _last = Duration.zero;
    }
    notifyListeners();
  }

  void _burst(CloudSprite s) {
    _haptics.burst();
    final big = s.units > 1;
    // A big cloud bursts harder: more puffs, flung further, a bigger kick.
    _pulseVelocity += big ? 9 : 6;
    final count = big ? 11 : 7;
    final size = big ? bigCloudScale : 1.0;
    for (var i = 0; i < count; i++) {
      final seed = s.slot * 31 + i * 7;
      final angle = i / count * 2 * math.pi + (_noise(seed) - 0.5) * 0.7;
      final speed = (0.26 + 0.2 * _noise(seed + 1)) * (big ? 1.25 : 1);
      _puffs.add(
        Puff(
          position: s.unitCenter,
          // A slight upward bias: the burst belongs to the evaporate, which
          // rises.
          velocity: Offset(
            math.cos(angle) * speed,
            math.sin(angle) * speed * 0.8 - 0.08,
          ),
          radius: (7 + 5 * _noise(seed + 2)) * size,
          life: 0.55 + 0.25 * _noise(seed + 3),
        ),
      );
    }
  }

  /// Deterministic 0 → 1 scatter. No Random, so the same cloud always bursts
  /// the same way and tests are repeatable.
  static double _noise(int n) {
    final x = math.sin(n * 12.9898) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void dispose() {
    _ticker.dispose();
    launches.dispose();
    super.dispose();
  }
}
