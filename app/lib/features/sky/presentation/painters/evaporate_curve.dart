import 'dart:math' as math;

import 'package:flutter/animation.dart';

import '../../domain/entities/cloud_sprite.dart';

typedef Stretch = ({double sx, double sy, double dy, double alpha});

/// Where in the exit the squash gives way to the burst. The sky spawns puffs,
/// kicks the sun and fires the haptic at exactly this point, so the pop lands
/// on the same frame the cloud starts to swell.
const double evaporateBurstAt = 0.24;

/// The exit: a deep squash, then a burst that swells and dissolves upward.
///
/// The squash is the anticipation beat. Without it the swell starts from a
/// dead stop and reads mechanical. Opacity deliberately does NOT move during
/// the squash — fading through the wind-up looks like a glitch rather than a
/// decision.
Stretch evaporateAt(double t) {
  if (t <= 0) return (sx: 1, sy: 1, dy: 0, alpha: 1);
  if (t >= 1) return (sx: 1.8, sy: 1.8, dy: -50, alpha: 0);

  if (t < evaporateBurstAt) {
    final k = Curves.easeOut.transform(t / evaporateBurstAt);
    return (sx: 1 + 0.10 * k, sy: 1 - 0.18 * k, dy: 5 * k, alpha: 1);
  }

  final u = (t - evaporateBurstAt) / (1 - evaporateBurstAt);
  // Out-cubic: fastest right at the burst, so the release feels like a pop.
  final k = Curves.easeOutCubic.transform(u);
  return (
    sx: 1.10 + 0.70 * k,
    sy: 0.82 + 0.98 * k,
    dy: 5 - 55 * k,
    // Quadratic so the cloud stays visible while it swells, then goes.
    alpha: 1 - u * u,
  );
}

/// A small cloud flying into a big one that is forming at [into]. It speeds
/// up as it goes, shrinks a little, and fades over the last stretch so it
/// reads as absorbed rather than vanishing on arrival.
({Offset center, double scale, double alpha}) gatherAt(
  double t, {
  required Offset from,
  required Offset into,
}) {
  if (t <= 0) return (center: from, scale: 1, alpha: 1);
  if (t >= 1) return (center: into, scale: 0.6, alpha: 0);
  final k = t * t;
  return (
    center: Offset.lerp(from, into, k)!,
    scale: 1 - 0.4 * k,
    alpha: t < 0.6 ? 1 : 1 - (t - 0.6) / 0.4,
  );
}

/// Where in an arrival the cloud touches down and the landing squash begins.
double landingAt(CloudEntry style) => switch (style) {
      CloudEntry.drop => 0.6,
      CloudEntry.launch => 0.72,
      CloudEntry.gather => 0.5,
      CloudEntry.condense => 1,
    };

typedef EntryPose = ({
  Offset center,
  double dy,
  double sx,
  double sy,
  double alpha,
});

/// A cloud arriving at [target]. [e] is 0 → 1 progress.
EntryPose entryPoseAt(
  CloudEntry style,
  double e, {
  required Offset target,
  Offset? origin,
}) {
  if (e >= 1) return (center: target, dy: 0, sx: 1, sy: 1, alpha: 1);
  final t = e.clamp(0.0, 1.0);

  if (style == CloudEntry.condense) {
    // Evaporate played backwards: gathers from a faint swell, sinks through
    // the squash and settles. Slower than the exit (see SkyController), so a
    // failed clear reads as the weather returning rather than a cheerful pop.
    final x = evaporateAt(1 - t);
    return (center: target, dy: x.dy, sx: x.sx, sy: x.sy, alpha: x.alpha);
  }

  final land = landingAt(style);
  if (t >= land) {
    // Squash on touchdown, a small stretch back, then rest.
    final u = (t - land) / (1 - land);
    final b = math.sin(u * 2 * math.pi) * (1 - u);
    return (center: target, dy: 0, sx: 1 + 0.14 * b, sy: 1 - 0.16 * b, alpha: 1);
  }

  final u = t / land;
  if (style == CloudEntry.gather) {
    // Swells up out of the small clouds arriving on its spot. Smoothstep, so
    // it eases out of nothing and into the landing squash.
    final k = u * u * (3 - 2 * u);
    final s = 0.55 + 0.45 * k;
    return (center: target, dy: 0, sx: s, sy: s, alpha: math.min(1, u / 0.3));
  }

  if (style == CloudEntry.launch && origin != null) {
    // Thrown fast, decelerating into the slot along an arc that rises above
    // both ends.
    final k = Curves.easeOutCubic.transform(u);
    final control = Offset(
      (origin.dx + target.dx) / 2,
      math.min(origin.dy, target.dy) - 0.18,
    );
    final center = origin * ((1 - k) * (1 - k)) +
        control * (2 * k * (1 - k)) +
        target * (k * k);
    final s = 0.45 + 0.55 * k;
    return (center: center, dy: 0, sx: s, sy: s, alpha: math.min(1, t / 0.08));
  }

  // Drop: accelerate down into place. Quadratic rather than easeIn, whose
  // slope is vertical at the end and would jump on the last frame.
  final fall = u * u;
  final s = 0.75 + 0.25 * fall;
  return (
    center: target,
    dy: -26 * (1 - fall),
    sx: s,
    sy: s,
    alpha: math.min(1, u / 0.35),
  );
}
