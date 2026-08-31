import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/user/user_profile.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/profile/data/in_memory_user_profile_repository.dart';
import 'package:habit_loop/slices/profile/ui/generic/display_name_provider.dart';
import 'package:habit_loop/slices/profile/ui/generic/enter_name_constants.dart';

import '../../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../../infrastructure/remote_config/fake_remote_config_service.dart';
import '../../../../infrastructure/sync/fake_sync_service.dart';

ProviderContainer _makeContainer({
  InMemoryUserProfileRepository? repository,
  FakeAnalyticsService? analytics,
  FakeSyncService? syncService,
  bool flagEnabled = true,
}) {
  return ProviderContainer(overrides: [
    userProfileRepositoryProvider.overrideWithValue(repository ?? InMemoryUserProfileRepository()),
    analyticsServiceProvider.overrideWithValue(analytics ?? FakeAnalyticsService()),
    syncServiceProvider.overrideWithValue(syncService ?? FakeSyncService()),
    remoteConfigServiceProvider.overrideWithValue(
      FakeRemoteConfigService(overrides: {'display_name_personalization_enabled': flagEnabled}),
    ),
  ]);
}

void main() {
  group('displayNameProvider', () {
    test('defaults to null with no seed', () {
      final container = _makeContainer();
      addTearDown(container.dispose);
      expect(container.read(displayNameProvider), isNull);
    });

    test('publishes has_display_name=false on build with no seed', () {
      final analytics = FakeAnalyticsService();
      final container = _makeContainer(analytics: analytics);
      addTearDown(container.dispose);
      container.read(displayNameProvider);
      expect(analytics.setUserProperties, contains((name: 'has_display_name', value: 'false')));
    });

    test('setDisplayName saves to the repository and updates state', () async {
      final repo = InMemoryUserProfileRepository();
      final container = _makeContainer(repository: repo);
      addTearDown(container.dispose);
      container.read(displayNameProvider);

      await container.read(displayNameProvider.notifier).setDisplayName('Yuriy');

      expect(container.read(displayNameProvider), 'Yuriy');
      expect((await repo.getProfile())?.displayName, 'Yuriy');
    });

    test('setDisplayName fires setUserProperty with has_display_name=true', () async {
      final analytics = FakeAnalyticsService();
      final container = _makeContainer(analytics: analytics);
      addTearDown(container.dispose);
      container.read(displayNameProvider);

      await container.read(displayNameProvider.notifier).setDisplayName('Yuriy');

      expect(analytics.setUserProperties.last, (name: 'has_display_name', value: 'true'));
    });

    test('refreshes from the repository when SyncService.pullCompleted fires', () async {
      final repo = InMemoryUserProfileRepository();
      final syncService = FakeSyncService();
      final container = _makeContainer(repository: repo, syncService: syncService);
      addTearDown(container.dispose);
      container.read(displayNameProvider);
      expect(container.read(displayNameProvider), isNull);

      await repo.saveProfile(UserProfile(displayName: 'Remote Name', updatedAt: DateTime.now()));
      syncService.emitPullCompleted();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(displayNameProvider), 'Remote Name');
    });

    test('pullCompleted refresh fires setUserProperty with the new value', () async {
      final repo = InMemoryUserProfileRepository();
      final syncService = FakeSyncService();
      final analytics = FakeAnalyticsService();
      final container = _makeContainer(repository: repo, syncService: syncService, analytics: analytics);
      addTearDown(container.dispose);
      container.read(displayNameProvider);
      analytics.reset();

      await repo.saveProfile(UserProfile(displayName: 'Remote Name', updatedAt: DateTime.now()));
      syncService.emitPullCompleted();
      await Future<void>.delayed(Duration.zero);

      expect(analytics.setUserProperties, contains((name: 'has_display_name', value: 'true')));
    });

    test('disposing the container cancels the pullCompleted subscription without throwing', () async {
      final syncService = FakeSyncService();
      final container = _makeContainer(syncService: syncService);
      container.read(displayNameProvider);
      container.dispose();

      // Should not throw even though the notifier is gone.
      syncService.emitPullCompleted();
      await Future<void>.delayed(Duration.zero);
    });

    test('setDisplayName uploads the profile via SyncService', () async {
      final syncService = FakeSyncService();
      final container = _makeContainer(syncService: syncService);
      addTearDown(container.dispose);
      container.read(displayNameProvider);

      await container.read(displayNameProvider.notifier).setDisplayName('Yuriy');

      expect(syncService.uploadedUserProfileCount, 1);
    });

    test('state updates after a build() re-execution (ref.invalidate), not just the first build', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);
      container.read(displayNameProvider);

      // Re-runs build() on the same Notifier instance without disposing the
      // container — regression guard for _disposed latching true forever.
      container.invalidate(displayNameProvider);
      container.read(displayNameProvider);

      await container.read(displayNameProvider.notifier).setDisplayName('Yuriy');

      expect(container.read(displayNameProvider), 'Yuriy');
    });
  });

  group('personalizedNameProvider', () {
    test('returns null when the flag is off, even with a name on file', () async {
      final container = _makeContainer(flagEnabled: false);
      addTearDown(container.dispose);
      container.read(displayNameProvider);

      await container.read(displayNameProvider.notifier).setDisplayName('Yuriy');

      expect(container.read(personalizedNameProvider), isNull);
    });

    test('mirrors displayNameProvider when the flag is on', () async {
      final container = _makeContainer(flagEnabled: true);
      addTearDown(container.dispose);
      container.read(displayNameProvider);
      await container.read(displayNameProvider.notifier).setDisplayName('Yuriy');

      expect(container.read(personalizedNameProvider), 'Yuriy');
    });

    test('is null when the flag is on but no name is on file', () {
      final container = _makeContainer(flagEnabled: true);
      addTearDown(container.dispose);
      expect(container.read(personalizedNameProvider), isNull);
    });

    test('caps an overlong name to enterNameMaxLength (HAB-232 WU6 audit finding)', () async {
      // setDisplayName has no cap of its own (only the UI entry points do) —
      // this simulates a name that arrived uncapped via a sync pull.
      final container = _makeContainer(flagEnabled: true);
      addTearDown(container.dispose);
      container.read(displayNameProvider);
      await container.read(displayNameProvider.notifier).setDisplayName('A' * 100);

      final personalized = container.read(personalizedNameProvider);
      expect(personalized, hasLength(enterNameMaxLength));
    });
  });
}
