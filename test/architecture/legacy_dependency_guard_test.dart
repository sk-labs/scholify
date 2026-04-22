import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'modern modules do not import legacy screens or legacy API services',
    () async {
      final root = Directory('lib');
      final targetPrefixes = ['lib/app/', 'lib/core/', 'lib/features/'];
      final violations = <String>[];

      await for (final entity in root.list(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }

        final normalizedPath = entity.path.replaceAll('\\', '/');
        final isTarget = targetPrefixes.any(
          (prefix) =>
              normalizedPath.startsWith(prefix) ||
              normalizedPath.contains('/$prefix'),
        );
        if (!isTarget) {
          continue;
        }

        final content = await entity.readAsString();
        final lines = content.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (!line.startsWith('import')) {
            continue;
          }

          final hasLegacyScreen =
              line.contains('/screens/') ||
              line.contains('package:scholify/screens/');
          final hasLegacyApi =
              line.contains('/services/api/') ||
              line.contains('package:scholify/services/api/');

          if (hasLegacyScreen || hasLegacyApi) {
            violations.add('$normalizedPath:${i + 1}: $line');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: violations.isEmpty
            ? null
            : 'Legacy dependencies found in modern modules:\n${violations.join('\n')}',
      );
    },
  );
}
