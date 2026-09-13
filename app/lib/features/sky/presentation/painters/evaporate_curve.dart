import 'package:flutter/animation.dart';

/// The exit you picked: a small squash, then a swell-and-dissolve in place.
///
/// The squash is the anticipation beat. Without it the scale-up starts from a
/// dead stop and reads mechanical. Opacity deliberately does NOT move during
/// the squash — fading through the wind-up makes it look like a glitch rather
/// than a decision.
const double _knee = 0.22;

({double sx, double sy, double dy, double alpha}) evaporateAt(double t) {
  if (t <= 0) return (sx: 1, sy: 1, dy: 0, alpha: 1);
  if (t >= 1) return (sx: 1.75, sy: 1.75, dy: -46, alpha: 0);

  if (t < _knee) {
    final k = t / _knee;
    return (sx: 1 + 0.06 * k, sy: 1 - 0.10 * k, dy: 4 * k, alpha: 1);
  }

  final k = Curves.easeInOut.transform((t - _knee) / (1 - _knee));
  return (
    sx: 1.06 + 0.69 * k,
    sy: 0.90 + 0.85 * k,
    dy: 4 - 50 * k,
    alpha: 1 - k,
  );
}

/// Pop-in for a newly added cloud, and for rollback when a clear fails.
({double scale, double alpha}) entryAt(double t) {
  if (t >= 1) return (scale: 1, alpha: 1);
  final k = Curves.easeOutBack.transform(t.clamp(0.0, 1.0));
  return (scale: 0.3 + 0.7 * k, alpha: t.clamp(0.0, 1.0));
}
