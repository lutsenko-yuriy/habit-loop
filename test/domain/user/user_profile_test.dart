import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/user/user_profile.dart';

void main() {
  group('UserProfile', () {
    test('creates a profile with a display name', () {
      final p = UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1));

      expect(p.displayName, 'Yuriy');
      expect(p.updatedAt, DateTime(2026, 8, 1));
    });

    test('creates a profile with a null display name — never entered, or deliberately skipped', () {
      final p = UserProfile(updatedAt: DateTime(2026, 8, 1));

      expect(p.displayName, isNull);
    });

    test('normalises an empty display name to null', () {
      final p = UserProfile(displayName: '', updatedAt: DateTime(2026, 8, 1));

      expect(p.displayName, isNull);
    });

    test('normalises a whitespace-only display name to null', () {
      final p = UserProfile(displayName: '   ', updatedAt: DateTime(2026, 8, 1));

      expect(p.displayName, isNull);
    });

    test('trims leading and trailing whitespace from a display name', () {
      final p = UserProfile(displayName: '  Yuriy  ', updatedAt: DateTime(2026, 8, 1));

      expect(p.displayName, 'Yuriy');
    });

    group('copyWith', () {
      test('preserves fields not passed', () {
        final p = UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1));

        final updated = p.copyWith(updatedAt: DateTime(2026, 8, 2));

        expect(updated.displayName, 'Yuriy');
        expect(updated.updatedAt, DateTime(2026, 8, 2));
      });

      test('overrides displayName when passed', () {
        final p = UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1));

        final updated = p.copyWith(displayName: 'Alex');

        expect(updated.displayName, 'Alex');
      });

      test('clearDisplayName sets displayName back to null', () {
        final p = UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1));

        final updated = p.copyWith(clearDisplayName: true);

        expect(updated.displayName, isNull);
      });

      test('normalises an empty or whitespace-only displayName to null, same as the constructor', () {
        final p = UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1));

        final updated = p.copyWith(displayName: '   ');

        expect(updated.displayName, isNull);
      });
    });

    test('two profiles with the same fields are equal', () {
      final a = UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1));
      final b = UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1));

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('profiles with different displayName are not equal', () {
      final a = UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1));
      final b = UserProfile(updatedAt: DateTime(2026, 8, 1));

      expect(a, isNot(equals(b)));
    });

    test('profiles with different updatedAt are not equal', () {
      final a = UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1));
      final b = UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 2));

      expect(a, isNot(equals(b)));
    });
  });
}
