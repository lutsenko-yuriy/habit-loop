import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/user/user_profile.dart';
import 'package:habit_loop/domain/user/user_profile_repository.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/profile/data/in_memory_user_profile_repository.dart';
import 'package:habit_loop/slices/profile/ui/generic/change_name_handler.dart';
import 'package:habit_loop/slices/profile/ui/generic/display_name_provider.dart';
import 'package:habit_loop/slices/profile/ui/generic/enter_name_constants.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/remote_config/fake_remote_config_service.dart';
import '../../../infrastructure/sync/fake_sync_service.dart';

/// Always throws on [saveProfile] — simulates a transient DB failure
/// (locked/closed, disk full) that `InMemoryUserProfileRepository` cannot.
class _ThrowingUserProfileRepository implements UserProfileRepository {
  @override
  Future<UserProfile?> getProfile() async => null;

  @override
  Future<void> saveProfile(UserProfile profile) async => throw Exception('write failed');
}

/// Minimal harness: a single button whose tap drives [openChangeNameDialog]
/// with a canned [dialogResult], recording whether the (fake) dialog was
/// actually invoked.
Widget _buildApp({
  required String? dialogResult,
  required UserProfileRepository userProfileRepository,
  FakeAnalyticsService? analyticsService,
  String? seedDisplayName,
  void Function(String currentNameSeenByDialog)? onDialogShown,
}) {
  return ProviderScope(
    overrides: [
      userProfileRepositoryProvider.overrideWithValue(userProfileRepository),
      syncServiceProvider.overrideWithValue(FakeSyncService()),
      // openChangeNameDialog reads personalizedNameProvider, which is gated by
      // this flag — real callers only ever reach this dialog while it's on
      // (the ⋯ menu entry itself is gated), so tests assume it's on too.
      remoteConfigServiceProvider.overrideWithValue(
        FakeRemoteConfigService(overrides: {'display_name_personalization_enabled': true}),
      ),
      if (analyticsService != null) analyticsServiceProvider.overrideWithValue(analyticsService),
      if (seedDisplayName != null)
        displayNameProvider.overrideWith(() => DisplayNameNotifier(seedDisplayName: seedDisplayName)),
    ],
    child: MaterialApp(
      home: Consumer(
        builder: (context, ref, _) => ElevatedButton(
          onPressed: () => openChangeNameDialog(
            context: context,
            ref: ref,
            showDialogFn: ({required context, required currentName}) async {
              onDialogShown?.call(currentName);
              return dialogResult;
            },
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  group('openChangeNameDialog', () {
    testWidgets('passes the current displayNameProvider value to the dialog', (tester) async {
      String? seenName;
      await tester.pumpWidget(_buildApp(
        dialogResult: null,
        userProfileRepository: InMemoryUserProfileRepository(),
        seedDisplayName: 'Alex',
        onDialogShown: (name) => seenName = name,
      ));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(seenName, 'Alex');
    });

    testWidgets('passes an empty string to the dialog when no name is on file', (tester) async {
      String? seenName;
      await tester.pumpWidget(_buildApp(
        dialogResult: null,
        userProfileRepository: InMemoryUserProfileRepository(),
        onDialogShown: (name) => seenName = name,
      ));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(seenName, '');
    });

    testWidgets('a null dialog result (cancelled) does not persist or fire display_name_changed', (tester) async {
      final analyticsService = FakeAnalyticsService();
      final userProfileRepository = InMemoryUserProfileRepository();
      await userProfileRepository.saveProfile(UserProfile(displayName: 'Alex', updatedAt: DateTime(2026, 1, 1)));

      await tester.pumpWidget(_buildApp(
        dialogResult: null,
        userProfileRepository: userProfileRepository,
        analyticsService: analyticsService,
        seedDisplayName: 'Alex',
      ));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();

      final saved = await userProfileRepository.getProfile();
      expect(saved?.displayName, 'Alex');
      expect(analyticsService.loggedEvents.any((e) => e.name == 'display_name_changed'), isFalse);
    });

    testWidgets('a non-null dialog result persists the new name and fires display_name_changed', (tester) async {
      final analyticsService = FakeAnalyticsService();
      final userProfileRepository = InMemoryUserProfileRepository();
      await userProfileRepository.saveProfile(UserProfile(displayName: 'Alex', updatedAt: DateTime(2026, 1, 1)));

      await tester.pumpWidget(_buildApp(
        dialogResult: 'Sam',
        userProfileRepository: userProfileRepository,
        analyticsService: analyticsService,
        seedDisplayName: 'Alex',
      ));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();

      final saved = await userProfileRepository.getProfile();
      expect(saved?.displayName, 'Sam');

      final event = analyticsService.loggedEvents.firstWhere((e) => e.name == 'display_name_changed');
      expect(event.toParameters()['name_length'], 3);
      expect(event.toParameters()['had_previous_name'], isTrue);
    });

    testWidgets('saving an empty name clears the stored display name (HAB-232)', (tester) async {
      final analyticsService = FakeAnalyticsService();
      final userProfileRepository = InMemoryUserProfileRepository();
      await userProfileRepository.saveProfile(UserProfile(displayName: 'Alex', updatedAt: DateTime(2026, 1, 1)));

      await tester.pumpWidget(_buildApp(
        dialogResult: '', // field cleared and saved
        userProfileRepository: userProfileRepository,
        analyticsService: analyticsService,
        seedDisplayName: 'Alex',
      ));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();

      final saved = await userProfileRepository.getProfile();
      expect(saved?.displayName, isNull);

      final event = analyticsService.loggedEvents.firstWhere((e) => e.name == 'display_name_changed');
      expect(event.toParameters()['name_length'], 0);
      expect(event.toParameters()['had_previous_name'], isTrue);
    });

    testWidgets('had_previous_name is false when no name was on file before the change', (tester) async {
      final analyticsService = FakeAnalyticsService();

      await tester.pumpWidget(_buildApp(
        dialogResult: 'Sam',
        userProfileRepository: InMemoryUserProfileRepository(),
        analyticsService: analyticsService,
      ));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();

      final event = analyticsService.loggedEvents.firstWhere((e) => e.name == 'display_name_changed');
      expect(event.toParameters()['had_previous_name'], isFalse);
    });

    testWidgets('saving the unchanged name is a no-op — no write, no analytics event', (tester) async {
      final analyticsService = FakeAnalyticsService();
      final userProfileRepository = InMemoryUserProfileRepository();
      final original = UserProfile(displayName: 'Alex', updatedAt: DateTime(2026, 1, 1));
      await userProfileRepository.saveProfile(original);

      await tester.pumpWidget(_buildApp(
        dialogResult: 'Alex', // same as the seeded/current name
        userProfileRepository: userProfileRepository,
        analyticsService: analyticsService,
        seedDisplayName: 'Alex',
      ));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();

      final saved = await userProfileRepository.getProfile();
      // updatedAt is unchanged — proves no re-save happened, not just that the
      // name string coincidentally matches.
      expect(saved?.updatedAt, original.updatedAt);
      expect(analyticsService.loggedEvents.any((e) => e.name == 'display_name_changed'), isFalse);
    });

    testWidgets('a repository failure is swallowed — no crash, no display_name_changed event', (tester) async {
      final analyticsService = FakeAnalyticsService();

      await tester.pumpWidget(_buildApp(
        dialogResult: 'Sam',
        userProfileRepository: _ThrowingUserProfileRepository(),
        analyticsService: analyticsService,
      ));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(analyticsService.loggedEvents.any((e) => e.name == 'display_name_changed'), isFalse);
    });

    testWidgets('caps a name longer than the max length, by grapheme cluster', (tester) async {
      final userProfileRepository = InMemoryUserProfileRepository();
      const familyEmoji = '👨‍👩‍👧‍👦'; // one grapheme cluster, 7 UTF-16 code units
      final longName = familyEmoji * 41;

      await tester.pumpWidget(_buildApp(
        dialogResult: longName,
        userProfileRepository: userProfileRepository,
      ));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();

      final saved = await userProfileRepository.getProfile();
      expect(saved?.displayName, familyEmoji * enterNameMaxLength);
    });

    testWidgets('fires the change_name screen view before showing the dialog', (tester) async {
      final analyticsService = FakeAnalyticsService();

      await tester.pumpWidget(_buildApp(
        dialogResult: null,
        userProfileRepository: InMemoryUserProfileRepository(),
        analyticsService: analyticsService,
      ));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(analyticsService.loggedScreens.any((s) => s.name == 'change_name'), isTrue);
    });
  });
}
