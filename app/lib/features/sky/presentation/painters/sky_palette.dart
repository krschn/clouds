import 'package:flutter/painting.dart';

/// How stormy the screen looks: 0 is a clear sky, 1 is as dark as it gets.
///
/// Full darkness lands at 1.5x capacity. suggestCentavosPerCloud aims months
/// at no more than 18 clouds, which is 1.5x the default 12, so the heaviest
/// normal month starts fully dark and every cloud cleared from there lightens
/// it. Capping at 1x instead would leave an overflow month sitting at max
/// darkness while the first several clears changed nothing.
///
/// Takes a fractional count because the sky glides between whole numbers.
double gloomFor(num cloudCount, int maxClouds) {
  if (maxClouds <= 0) return 0;
  return (cloudCount / (maxClouds * 1.5)).clamp(0.0, 1.0).toDouble();
}

/// Every colour on the main screen, derived from gloom alone so no surface can
/// disagree with another about how heavy the month is.
class SkyPalette {
  const SkyPalette({
    required this.skyTop,
    required this.skyBottom,
    required this.cloud,
    required this.sunCore,
    required this.sunRay,
    required this.glow,
    required this.page,
    required this.ink,
    required this.chip,
  });

  final Color skyTop;
  final Color skyBottom;
  final Color cloud;
  final Color sunCore;
  final Color sunRay;

  /// Warm light around the sun. Fades out as the sky darkens.
  final Color glow;

  /// Behind the bill list.
  final Color page;

  /// Menu icon and caption text.
  final Color ink;

  /// Backing for the caption, so it stays readable over any sky.
  final Color chip;

  bool get darkChrome => ink == _white;
}

const Color _white = Color(0xFFFFFFFF);
const Color _navy = Color(0xFF0C447C);

// Three stops rather than two: a straight clear-to-storm blend passes through
// a muddy grey. Every channel only ever decreases along each ramp, which is
// what guarantees more gloom never makes a surface lighter.
Color _ramp(double g, Color clear, Color overcast, Color storm) {
  if (g <= 0) return clear;
  if (g >= 1) return storm;
  return g < 0.5
      ? Color.lerp(clear, overcast, g * 2)!
      : Color.lerp(overcast, storm, (g - 0.5) * 2)!;
}

SkyPalette paletteFor(double gloom) {
  final g = gloom.clamp(0.0, 1.0);

  final skyTop = _ramp(
    g,
    const Color(0xFFCFE6FA),
    const Color(0xFF9FB3C6),
    const Color(0xFF3C4A59),
  );

  // Whichever of navy or white stands out more against the top of the sky,
  // where the menu icon sits. The switch happens where both are about equal,
  // so it never reads as a jump.
  final top = skyTop.computeLuminance();
  final onNavy = (top + 0.05) / (_navy.computeLuminance() + 0.05);
  final onWhite = 1.05 / (top + 0.05);
  final dark = onWhite > onNavy;

  return SkyPalette(
    skyTop: skyTop,
    skyBottom: _ramp(
      g,
      const Color(0xFFF1F7FD),
      const Color(0xFFB9C6D2),
      const Color(0xFF5A6877),
    ),
    cloud: _ramp(g, _white, const Color(0xFFE4E9EE), const Color(0xFF9AA6B2)),
    sunCore: Color.lerp(const Color(0xFFEF9F27), const Color(0xFF9E7424), g)!,
    sunRay: Color.lerp(const Color(0xFFFAC775), const Color(0xFF7D6A4F), g)!,
    glow: const Color(0xFFFFE2A6).withValues(alpha: 1 - g),
    page: _ramp(
      g,
      const Color(0xFFF4F8FC),
      const Color(0xFFDDE4EB),
      const Color(0xFFB4BFCA),
    ),
    ink: dark ? _white : _navy,
    chip: dark ? const Color(0xFF2A3642) : const Color(0xFFF2F7FC),
  );
}
