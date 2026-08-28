import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/user/user_profile.dart';
import 'package:habit_loop/infrastructure/persistence/habit_loop_database.dart';
import 'package:habit_loop/slices/profile/data/sqlite_user_profile_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SqliteUserProfileRepository', () {
    late Database db;
    late SqliteUserProfileRepository repository;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1, onCreate: HabitLoopDatabase.runMigrations),
      );
      repository = SqliteUserProfileRepository(db);
    });

    tearDown(() async => db.close());

    // -------------------------------------------------------------------------
    // getProfile
    // -------------------------------------------------------------------------

    group('getProfile', () {
      test('returns null when no profile has been saved yet', () async {
        expect(await repository.getProfile(), isNull);
      });

      test('returns the saved profile', () async {
        await repository.saveProfile(UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1)));

        final profile = await repository.getProfile();
        expect(profile?.displayName, equals('Yuriy'));
        expect(profile?.updatedAt, equals(DateTime(2026, 8, 1)));
      });
    });

    // -------------------------------------------------------------------------
    // saveProfile — upsert / single-row invariant
    // -------------------------------------------------------------------------

    group('saveProfile', () {
      test('a second save overwrites the first — single-row invariant', () async {
        await repository.saveProfile(UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1)));
        await repository.saveProfile(UserProfile(displayName: 'Alex', updatedAt: DateTime(2026, 8, 2)));

        final rows = await db.query('user_profile');
        expect(rows, hasLength(1));
        expect(rows.single['display_name'], equals('Alex'));
      });

      test('saving a null display name clears a previously-set one', () async {
        await repository.saveProfile(UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1)));
        await repository.saveProfile(UserProfile(updatedAt: DateTime(2026, 8, 2)));

        final profile = await repository.getProfile();
        expect(profile?.displayName, isNull);
      });

      test('a fresh save starts dirty', () async {
        await repository.saveProfile(UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1)));

        final rows = await db.query('user_profile');
        expect(rows.single['dirty'], equals(1));
      });
    });

    // -------------------------------------------------------------------------
    // getDirtyUserProfile
    // -------------------------------------------------------------------------

    group('getDirtyUserProfile', () {
      test('returns null when no profile has been saved yet', () async {
        expect(await repository.getDirtyUserProfile(), isNull);
      });

      test('returns the profile right after saving — unsync\'d local change', () async {
        await repository.saveProfile(UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1)));

        final dirty = await repository.getDirtyUserProfile();
        expect(dirty?.displayName, equals('Yuriy'));
      });

      test('returns null after markUserProfileSynced', () async {
        await repository.saveProfile(UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1)));
        await repository.markUserProfileSynced(DateTime(2026, 8, 1, 12));

        expect(await repository.getDirtyUserProfile(), isNull);
      });

      test('re-appears as dirty after a subsequent saveProfile', () async {
        await repository.saveProfile(UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1)));
        await repository.markUserProfileSynced(DateTime(2026, 8, 1, 12));
        await repository.saveProfile(UserProfile(displayName: 'Alex', updatedAt: DateTime(2026, 8, 2)));

        final dirty = await repository.getDirtyUserProfile();
        expect(dirty?.displayName, equals('Alex'));
      });
    });

    // -------------------------------------------------------------------------
    // markUserProfileSynced / getUserProfileSyncedAt
    // -------------------------------------------------------------------------

    group('getUserProfileSyncedAt', () {
      test('returns null when no profile has been saved yet', () async {
        expect(await repository.getUserProfileSyncedAt(), isNull);
      });

      test('returns null when the profile is dirty (never synced)', () async {
        await repository.saveProfile(UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1)));
        expect(await repository.getUserProfileSyncedAt(), isNull);
      });

      test('returns the syncedAt timestamp after markUserProfileSynced', () async {
        final syncedAt = DateTime(2026, 8, 1, 12, 0);
        await repository.saveProfile(UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1)));
        await repository.markUserProfileSynced(syncedAt);

        final result = await repository.getUserProfileSyncedAt();
        expect(result, isNotNull);
        expect(result!.millisecondsSinceEpoch, syncedAt.millisecondsSinceEpoch);
      });

      test('returns null again after a subsequent saveProfile re-dirtifies the record', () async {
        await repository.saveProfile(UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1)));
        await repository.markUserProfileSynced(DateTime(2026, 8, 1, 12));
        await repository.saveProfile(UserProfile(displayName: 'Alex', updatedAt: DateTime(2026, 8, 2)));

        expect(await repository.getUserProfileSyncedAt(), isNull);
      });
    });

    // -------------------------------------------------------------------------
    // markUserProfileDirty
    // -------------------------------------------------------------------------

    group('markUserProfileDirty', () {
      test('re-dirtifies a previously-synced profile', () async {
        await repository.saveProfile(UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1)));
        await repository.markUserProfileSynced(DateTime(2026, 8, 1, 12));
        expect(await repository.getDirtyUserProfile(), isNull);

        await repository.markUserProfileDirty();

        final dirty = await repository.getDirtyUserProfile();
        expect(dirty?.displayName, equals('Yuriy'));
      });

      test('is a no-op when no profile has been saved yet', () async {
        await expectLater(repository.markUserProfileDirty(), completes);
        expect(await repository.getProfile(), isNull);
      });

      test('getUserProfileSyncedAt returns null after markUserProfileDirty', () async {
        await repository.saveProfile(UserProfile(displayName: 'Yuriy', updatedAt: DateTime(2026, 8, 1)));
        await repository.markUserProfileSynced(DateTime(2026, 8, 1, 12));
        expect(await repository.getUserProfileSyncedAt(), isNotNull);

        await repository.markUserProfileDirty();

        expect(await repository.getUserProfileSyncedAt(), isNull);
      });
    });
  });
}
