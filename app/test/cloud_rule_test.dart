import 'dart:convert';
import 'dart:io';

import 'package:cloud_payments/features/sky/domain/entities/cloud_rule.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads the same fixture as backend/src/sky/domain/cloud-rule.spec.ts.
/// If someone changes the rule in one language, this goes red.
void main() {
  final fixture = jsonDecode(
    File('../shared/cloud-rule.vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('agrees with the TypeScript implementation on minScale', () {
    expect(CloudRule.minScale, fixture['minScale']);
  });

  for (final raw in fixture['cases'] as List<dynamic>) {
    final v = raw as Map<String, dynamic>;
    test(v['name'] as String, () {
      final rule = CloudRule(
        centavosPerCloud: v['centavosPerCloud'] as int,
        maxClouds: v['maxClouds'] as int,
      );
      expect(rule.cloudsFor(v['outstandingCentavos'] as int), v['cloudCount']);
      expect(
        rule.scaleFor(v['cloudCount'] as int),
        closeTo((v['cloudScale'] as num).toDouble(), 1e-6),
      );
    });
  }
}
