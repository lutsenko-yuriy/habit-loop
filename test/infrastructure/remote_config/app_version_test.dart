import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/app_version.dart';

void main() {
  group('currentAppVersion', () {
    test('stays in sync with pubspec.yaml\'s version', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true).firstMatch(pubspec);
      expect(match, isNotNull, reason: 'could not find a version: line in pubspec.yaml');
      expect(
        currentAppVersion,
        match!.group(1),
        reason: 'currentAppVersion must be bumped in the same commit as pubspec.yaml\'s version — '
            'ship bumps pubspec.yaml AFTER this PR merges, so if this fails, currentAppVersion is '
            'stale-by-one and any release-version-gated flag could stay hidden in the release it '
            'was meant to ship in.',
      );
    });
  });

  group('isAtLeast', () {
    test('equal versions satisfy the requirement', () {
      expect(isAtLeast('0.53.0', '0.53.0'), isTrue);
    });

    test('greater major version satisfies the requirement', () {
      expect(isAtLeast('1.0.0', '0.53.0'), isTrue);
    });

    test('lesser major version does not satisfy the requirement', () {
      expect(isAtLeast('0.52.0', '1.0.0'), isFalse);
    });

    test('greater minor version satisfies the requirement', () {
      expect(isAtLeast('0.54.0', '0.53.0'), isTrue);
    });

    test('lesser minor version does not satisfy the requirement', () {
      expect(isAtLeast('0.52.9', '0.53.0'), isFalse);
    });

    test('greater patch version satisfies the requirement', () {
      expect(isAtLeast('0.53.1', '0.53.0'), isTrue);
    });

    test('lesser patch version does not satisfy the requirement', () {
      expect(isAtLeast('0.53.0', '0.53.1'), isFalse);
    });

    test('missing trailing segment is treated as zero (current)', () {
      expect(isAtLeast('1.2', '1.2.0'), isTrue);
    });

    test('missing trailing segment is treated as zero (required)', () {
      expect(isAtLeast('1.2.0', '1.2'), isTrue);
    });

    test('missing trailing segment correctly fails when short of requirement', () {
      expect(isAtLeast('1.2', '1.2.1'), isFalse);
    });

    test('non-numeric current version is treated defensively as not satisfied', () {
      expect(isAtLeast('not-a-version', '0.53.0'), isFalse);
    });

    test('non-numeric required version is treated defensively as not satisfied', () {
      expect(isAtLeast('0.53.0', 'not-a-version'), isFalse);
    });

    test('empty strings are treated defensively as not satisfied', () {
      expect(isAtLeast('', ''), isFalse);
    });
  });
}
