import 'dart:math' as math;
import 'dart:ui';

import '../../domain/entities/cloud_sprite.dart';
import '../../domain/usecases/group_clouds.dart';
import 'evaporate_curve.dart';

/// Everything the painter needs to draw one cloud this frame.
///
/// [center] is in unit sky coordinates. [dy] is in the cloud path's authored
/// units, so the rise and fall scale with the clouds.
typedef CloudPose = ({
  Offset center,
  double dy,
  double sx,
  double sy,
  double alpha,
});

/// How far a fully tense cloud wanders from its slot, in unit coordinates.
const double _trembleReach = 0.006;

/// Combines arrival, exit, size and hold tension into one pose. Pure, so the
/// painter holds no animation logic and every motion can be tested without a
/// canvas.
CloudPose poseOf(CloudSprite s, {required double time}) {
  final enter = entryPoseAt(
    s.entryStyle,
    s.entry,
    target: s.unitCenter,
    origin: s.origin,
  );

  var center = enter.center;
  var dy = enter.dy;
  var sx = enter.sx;
  var sy = enter.sy;
  var alpha = enter.alpha;

  final into = s.mergeInto;
  if (s.exiting && into != null) {
    final g = gatherAt(s.t, from: enter.center, into: into);
    center = g.center;
    sx *= g.scale;
    sy *= g.scale;
    alpha *= g.alpha;
  } else {
    final exit = evaporateAt(s.exiting ? s.t : 0);
    dy += exit.dy;
    sx *= exit.sx;
    sy *= exit.sy;
    alpha *= exit.alpha;
  }

  if (s.units > 1) {
    sx *= bigCloudScale;
    sy *= bigCloudScale;
  }

  if (s.tension > 0) {
    // Incommensurate frequencies, phased by slot, so neighbouring clouds
    // shiver independently instead of in lockstep.
    final reach = _trembleReach * s.tension;
    center += Offset(
      math.sin(time * 47 + s.slot * 1.7) * reach,
      math.cos(time * 59 + s.slot * 2.3) * reach * 0.7,
    );
    final breathe = math.sin(time * 31 + s.slot) * 0.025 * s.tension;
    sx *= 1 + breathe;
    sy *= 1 - breathe;
  }

  return (center: center, dy: dy, sx: sx, sy: sy, alpha: alpha);
}
