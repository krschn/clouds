import '../../../sky/domain/usecases/group_clouds.dart';

/// The words for a number of clouds, in the sizes the sky actually draws. A
/// count of single clouds would say "10" where the sky shows two big ones.

String _sized(int n, String size) => '$n $size cloud${n == 1 ? '' : 's'}';

/// For sentences: "Adds 1 big cloud and 2 small".
String cloudPhrase(int count) {
  final g = cloudGroups(count);
  if (g.big == 0 && g.small == 0) return 'no clouds';
  if (g.big == 0) return _sized(g.small, 'small');
  if (g.small == 0) return _sized(g.big, 'big');
  return '${_sized(g.big, 'big')} and ${g.small} small';
}

/// For the caption and the month list: "2 big, 3 small".
String cloudSummary(int count) {
  final g = cloudGroups(count);
  if (g.big == 0 && g.small == 0) return 'Clear';
  if (g.big == 0) return _sized(g.small, 'small');
  if (g.small == 0) return _sized(g.big, 'big');
  return '${g.big} big, ${g.small} small';
}
