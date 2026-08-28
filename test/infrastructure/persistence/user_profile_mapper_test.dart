import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/user/user_profile.dart';
import 'package:habit_loop/infrastructure/persistence/user_profile_mapper.dart';

void main() {
  final updatedAt = DateTime(2026, 8, 1, 9, 0);

  group('UserProfileMapper', () {
    group('toRow', () {
      test('always writes the fixed single-row id', () {
        final row = UserProfileMapper.toRow(UserProfile(updatedAt: updatedAt));
        expect(row['id'], equals('local'));
      });

      test('maps displayName when set', () {
        final row = UserProfileMapper.toRow(UserProfile(displayName: 'Yuriy', updatedAt: updatedAt));
        expect(row['display_name'], equals('Yuriy'));
      });

      test('maps displayName as null when unset', () {
        final row = UserProfileMapper.toRow(UserProfile(updatedAt: updatedAt));
        expect(row['display_name'], isNull);
      });

      test('maps updatedAt as epoch milliseconds', () {
        final row = UserProfileMapper.toRow(UserProfile(updatedAt: updatedAt));
        expect(row['updated_at'], equals(updatedAt.millisecondsSinceEpoch));
      });

      test('always writes dirty=1 — every insert/update is queued for sync', () {
        final row = UserProfileMapper.toRow(UserProfile(updatedAt: updatedAt));
        expect(row['dirty'], equals(1));
      });

      test('always writes synced_at=null — managed exclusively by the sync layer', () {
        final row = UserProfileMapper.toRow(UserProfile(updatedAt: updatedAt));
        expect(row['synced_at'], isNull);
      });
    });

    group('fromRow', () {
      Map<String, dynamic> baseRow() => {
            'id': 'local',
            'display_name': null,
            'updated_at': updatedAt.millisecondsSinceEpoch,
            'dirty': 1,
            'synced_at': null,
          };

      test('reconstructs displayName as null when absent', () {
        expect(UserProfileMapper.fromRow(baseRow()).displayName, isNull);
      });

      test('reconstructs displayName when present', () {
        final row = baseRow()..['display_name'] = 'Yuriy';
        expect(UserProfileMapper.fromRow(row).displayName, equals('Yuriy'));
      });

      test('reconstructs updatedAt correctly', () {
        expect(UserProfileMapper.fromRow(baseRow()).updatedAt, equals(updatedAt));
      });

      test('reconstructs updatedAt as local-time DateTime (not UTC)', () {
        expect(UserProfileMapper.fromRow(baseRow()).updatedAt.isUtc, isFalse);
      });

      test('id, dirty and synced_at columns in row are ignored — not on domain model', () {
        final row = baseRow()
          ..['id'] = 'local'
          ..['dirty'] = 0
          ..['synced_at'] = DateTime(2026, 8, 2).millisecondsSinceEpoch;
        expect(() => UserProfileMapper.fromRow(row), returnsNormally);
      });
    });

    group('round-trip', () {
      test('profile with a display name round-trips correctly', () {
        final original = UserProfile(displayName: 'Yuriy', updatedAt: updatedAt);
        final restored = UserProfileMapper.fromRow(UserProfileMapper.toRow(original));
        expect(restored, equals(original));
      });

      test('profile with a null display name round-trips correctly', () {
        final original = UserProfile(updatedAt: updatedAt);
        final restored = UserProfileMapper.fromRow(UserProfileMapper.toRow(original));
        expect(restored, equals(original));
      });
    });
  });
}
