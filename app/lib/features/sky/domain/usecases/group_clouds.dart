/// How many clouds one big cloud stands for.
///
/// Display only. The count, the caption, the darkness and both CloudRule
/// implementations still work in single clouds, so nothing about grouping
/// crosses the API or the shared vectors.
const int cloudsPerBigCloud = 5;

/// A big cloud is this much wider and taller than a small one. Area goes with
/// the square, so it covers about 2.6 small clouds' worth of sky: reads as
/// heavier without five times the white.
const double bigCloudScale = 1.6;

typedef CloudGroups = ({int big, int small});

/// How [count] clouds are drawn: as many big clouds as fit, the rest small.
CloudGroups cloudGroups(int count) {
  if (count <= 0) return (big: 0, small: 0);
  return (big: count ~/ cloudsPerBigCloud, small: count % cloudsPerBigCloud);
}

int unitsIn(CloudGroups groups) =>
    groups.big * cloudsPerBigCloud + groups.small;

/// How many small clouds' worth of sky [groups] covers. This, not the cloud
/// count, is what the overcapacity shrink should respond to.
int paintedCount(CloudGroups groups) =>
    (groups.big * bigCloudScale * bigCloudScale + groups.small).ceil();
