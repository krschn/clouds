import 'dart:math' as math;
import 'dart:ui';

import '../../domain/usecases/layout_clouds.dart';

/// How many flame tongues ring the sun.
const int sunTongues = 9;

/// How far the longest flames reach, in disc radii.
const double sunOuterReach = 1.7;

/// Where the flame ring starts, in disc radii. Between the disc and this is
/// the gap that lets the sky show through.
const double _flameInner = 1.14;

/// Where the band the tongues rise from ends, in disc radii.
const double _bandOuter = 1.28;

/// How much each effect can grow the sun, as a fraction of its radius.
const double sunClaritySwell = 0.12;
const double sunPulseSwell = 0.06;
const double sunPulseMax = 1.5;
const double sunBloomSwell = 0.2;

/// The biggest the sun ever gets relative to its laid-out radius: a clear
/// sky, the strongest pulse and the peak of the finale bloom at once.
const double maxSunSwell = (1 + sunClaritySwell) *
    (1 + sunPulseSwell * sunPulseMax) *
    (1 + sunBloomSwell);

/// Breathing room between the sun's furthest flame and the notch or edge.
const double _margin = 6;

/// The part of the sky that clouds and the sun are laid out in: everything
/// below [topInset], so nothing is drawn behind a notch, Dynamic Island or
/// status bar. The sky's colour still fills the whole box.
Rect skyStage(Size sky, {double topInset = 0}) =>
    Rect.fromLTRB(0, math.min(topInset, sky.height), sky.width, sky.height);

/// A point in unit sky coordinates, placed inside [stage].
Offset stagePoint(Rect stage, Offset unit) => Offset(
      stage.left + unit.dx * stage.width,
      stage.top + unit.dy * stage.height,
    );

typedef SunLayout = ({Offset center, double radius});

/// Where the sun sits and how big its disc is before any swell.
///
/// Its natural size follows the stage, but it is capped so that even at
/// [maxSunSwell] the flames stop short of the top inset and the sides. A tall
/// sky gets its natural sun; a short one, or one under a deep notch, gets a
/// smaller one rather than flames under the Dynamic Island.
SunLayout sunLayout(Size sky, {double topInset = 0}) {
  final stage = skyStage(sky, topInset: topInset);
  final center = stagePoint(stage, sunUnitCenter);
  final natural = stage.shortestSide * 0.22;
  final room = math.min(
        center.dy - stage.top,
        math.min(center.dx, sky.width - center.dx),
      ) -
      _margin;
  final fits = math.max(0.0, room) / (maxSunSwell * sunOuterReach);
  return (center: center, radius: math.min(natural, fits));
}

Offset _polar(double r, double angle) =>
    Offset(math.cos(angle) * r, math.sin(angle) * r);

Path _circle(Offset center, double radius) =>
    Path()..addOval(Rect.fromCircle(center: center, radius: radius));

/// The flame ring for a disc of [radius], centred on the origin: a band just
/// outside the gap, with [sunTongues] flames rising from it, alternately large
/// and small.
///
/// Each flame is a curl: a curved stem sweeps up out of the band into a round
/// lobe, a smaller circle bites into the lobe's trailing side so it hooks
/// over with a hole in its crook, and a short flick trails off the top. All
/// of it is simple shapes combined, so it scales crisply and takes the sky's
/// colours. [phase] rotates the ring.
Path buildSunFlames({required double radius, double phase = 0}) {
  const step = 2 * math.pi / sunTongues;
  final band = radius * _bandOuter;

  var ring = Path.combine(
    PathOperation.difference,
    _circle(Offset.zero, band),
    _circle(Offset.zero, radius * _flameInner),
  );
  final bites = Path();

  for (var i = 0; i < sunTongues; i++) {
    final a = phase + i * step;
    final size = i.isEven ? 1.0 : 0.8;

    // The lobe's outer edge is the flame's furthest reach.
    final lobe = radius * 0.24 * size;
    final reach = radius * sunOuterReach * (i.isEven ? 1 : 0.95);
    final d = reach - lobe;
    final spread = lobe / d; // the lobe's angular radius

    Offset at(double r, double angle) => _polar(r, a + angle);

    // Stem: from a wide root in the band, sweeping forward into the lobe.
    // It starts inside the band, never below it, so the gap stays round.
    final rootIn = band - radius * 0.06;
    final stem = Path();
    final p0 = at(rootIn, -spread * 2.2);
    stem.moveTo(p0.dx, p0.dy);
    final c1 = at(d * 0.92, -spread * 2.4);
    final p1 = at(d, -spread * 0.9);
    stem.quadraticBezierTo(c1.dx, c1.dy, p1.dx, p1.dy);
    final p2 = at(d - lobe * 0.2, spread * 0.3);
    stem.lineTo(p2.dx, p2.dy);
    final c2 = at(band + radius * 0.05, spread * 0.9);
    final p3 = at(rootIn, spread * 0.6);
    stem.quadraticBezierTo(c2.dx, c2.dy, p3.dx, p3.dy);
    stem.close();

    // Flick: a short tail trailing forward off the top of the lobe.
    final flick = Path();
    final f0 = at(d + lobe * 0.55, -spread * 0.2);
    flick.moveTo(f0.dx, f0.dy);
    final fc = at(d + lobe * 0.95, -spread * 1.1);
    final f1 = at(d + lobe * 0.6, -spread * 1.8);
    flick.quadraticBezierTo(fc.dx, fc.dy, f1.dx, f1.dy);
    final f2 = at(d + lobe * 0.1, -spread * 0.7);
    flick.lineTo(f2.dx, f2.dy);
    flick.close();

    ring = Path.combine(PathOperation.union, ring, stem);
    ring = Path.combine(PathOperation.union, ring, _circle(at(d, 0), lobe));
    ring = Path.combine(PathOperation.union, ring, flick);

    // The bite that makes the hook: set back and to the trailing side, so it
    // breaks through the lobe's edge there and leaves a hole in the crook.
    bites.addOval(
      Rect.fromCircle(
        center: at(d - lobe * 0.15, spread * 0.55),
        radius: lobe * 0.52,
      ),
    );
  }

  return Path.combine(PathOperation.difference, ring, bites);
}
