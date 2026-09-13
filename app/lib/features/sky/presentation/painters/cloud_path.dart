import 'dart:ui';

/// One cloud, centred on the origin, roughly 100 units wide.
///
/// Built once and reused for every sprite. All sub-paths wind the same way so
/// the default non-zero fill unions them instead of punching holes.
Path buildCloudPath() {
  return Path()
    ..addOval(Rect.fromCenter(center: const Offset(-20, 6), width: 44, height: 34))
    ..addOval(Rect.fromCenter(center: const Offset(6, -2), width: 52, height: 42))
    ..addOval(Rect.fromCenter(center: const Offset(26, 8), width: 40, height: 32))
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(3, 10), width: 58, height: 19),
        const Radius.circular(9),
      ),
    );
}
