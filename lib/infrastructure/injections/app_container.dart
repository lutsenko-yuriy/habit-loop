import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_sync_repository.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/domain/showup/showup_sync_repository.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_service.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_service.dart';
import 'package:habit_loop/infrastructure/crashlytics/contracts/crashlytics_service.dart';
import 'package:habit_loop/infrastructure/device/contracts/device_id_service.dart';
import 'package:habit_loop/infrastructure/firestore/contracts/firestore_client.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/locale/contracts/locale_preference_service.dart';
import 'package:habit_loop/infrastructure/logging/contracts/log_service.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';
import 'package:habit_loop/infrastructure/onboarding/contracts/onboarding_preference_service.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_override_store.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';

/// Composition root. Knows which instances to wire to which providers;
/// `main.dart` knows how to construct those instances.
/// Mode-agnostic — no kReleaseMode checks here.
abstract final class AppContainer {
  /// `async` because it fetches the saved locale before building the list so
  /// [localeOverrideProvider] is populated on the first frame.
  /// `null` parameters fall back to their noop provider defaults.
  static Future<List<Override>> overrides({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
    required PactTransactionService transactionService,
    PactSyncRepository? pactSyncRepository,
    ShowupSyncRepository? showupSyncRepository,
    AnalyticsService? analyticsService,
    CrashlyticsService? crashlyticsService,
    LogService? logService,
    RemoteConfigService? remoteConfigService,
    RemoteConfigOverrideStore? remoteConfigOverrideStore,
    NotificationService? notificationService,
    LocalePreferenceService? localePreferenceService,
    OnboardingPreferenceService? onboardingPreferenceService,
    AuthService? authService,
    DeviceIdService? deviceIdService,
    FirestoreClient? firestoreClient,
    Object? fakeFirestoreClient,
    String? debugBackendAtStartup,
  }) async {
    Locale? initialLocale;
    if (localePreferenceService != null) {
      initialLocale = await localePreferenceService.getSavedLocale();
    }

    return [
      pactRepositoryProvider.overrideWithValue(pactRepository),
      showupRepositoryProvider.overrideWithValue(showupRepository),
      pactTransactionServiceProvider.overrideWithValue(transactionService),
      if (pactSyncRepository != null) pactSyncRepositoryProvider.overrideWithValue(pactSyncRepository),
      if (showupSyncRepository != null) showupSyncRepositoryProvider.overrideWithValue(showupSyncRepository),
      if (logService != null) logServiceProvider.overrideWithValue(logService),
      if (analyticsService != null) analyticsServiceProvider.overrideWithValue(analyticsService),
      if (crashlyticsService != null) crashlyticsServiceProvider.overrideWithValue(crashlyticsService),
      if (remoteConfigService != null) remoteConfigServiceProvider.overrideWithValue(remoteConfigService),
      if (remoteConfigOverrideStore != null)
        remoteConfigOverrideStoreProvider.overrideWithValue(remoteConfigOverrideStore),
      if (notificationService != null) notificationServiceProvider.overrideWithValue(notificationService),
      if (localePreferenceService != null) localePreferenceServiceProvider.overrideWithValue(localePreferenceService),
      if (initialLocale != null) localeOverrideProvider.overrideWith((ref) => initialLocale!),
      if (onboardingPreferenceService != null)
        onboardingPreferenceServiceProvider.overrideWithValue(onboardingPreferenceService),
      if (authService != null) authServiceProvider.overrideWithValue(authService),
      if (deviceIdService != null) deviceIdServiceProvider.overrideWithValue(deviceIdService),
      if (firestoreClient != null) firestoreClientProvider.overrideWithValue(firestoreClient),
      if (fakeFirestoreClient != null) fakeFirestoreClientProvider.overrideWithValue(fakeFirestoreClient),
      if (debugBackendAtStartup != null) debugBackendAtStartupProvider.overrideWithValue(debugBackendAtStartup),
    ];
  }
}
