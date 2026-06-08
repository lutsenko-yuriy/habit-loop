import 'dart:async' show Completer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_link_exception.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/onboarding_sign_in_controller.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_status_view_model.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_ui_state.dart';

import '../../../../infrastructure/remote_config/fake_remote_config_service.dart';

class _FakeSyncStatusViewModel extends AutoDisposeNotifier<SyncUiState> implements SyncStatusViewModel {
  final bool throwOnLink;

  _FakeSyncStatusViewModel({this.throwOnLink = false});

  @override
  SyncUiState build() => SyncUiState.synced;

  @override
  Future<void> linkWithGoogle() async {
    if (throwOnLink) throw const AuthLinkException(code: 'test-error');
  }

  @override
  Future<void> triggerManualSync() async {}

  @override
  Future<int> fullSync() async => 0;

  @override
  Future<void> signOut() async {}
}

class _SignInTrigger extends ConsumerWidget {
  final void Function() onDialogShown;

  const _SignInTrigger({required this.onDialogShown});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSigningIn = ref.watch(onboardingSignInLoadingProvider);
    return Column(
      children: [
        if (isSigningIn) const CircularProgressIndicator(key: Key('spinner')),
        ElevatedButton(
          key: const Key('sign-in'),
          onPressed: () => unawaited(OnboardingSignInController.signIn(
            ref: ref,
            context: context,
            showFailureDialog: (_) async => onDialogShown(),
          )),
          child: const Text('Sign In'),
        ),
      ],
    );
  }
}

Widget _buildApp({bool throwOnLink = false, void Function()? onDialogShown}) {
  return ProviderScope(
    overrides: [
      remoteConfigServiceProvider.overrideWithValue(
        FakeRemoteConfigService(overrides: {'onboarding_auto_advance_seconds': 0}),
      ),
      syncStatusViewModelProvider.overrideWith(() => _FakeSyncStatusViewModel(throwOnLink: throwOnLink)),
      hasActivePactsProvider.overrideWith((ref) async => false),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: _SignInTrigger(onDialogShown: onDialogShown ?? () {})),
    ),
  );
}

void main() {
  testWidgets('shows spinner while sign-in is in progress', (tester) async {
    final completer = Completer<bool>();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        remoteConfigServiceProvider.overrideWithValue(
          FakeRemoteConfigService(overrides: {'onboarding_auto_advance_seconds': 0}),
        ),
        syncStatusViewModelProvider.overrideWith(() => _FakeSyncStatusViewModel()),
        hasActivePactsProvider.overrideWith((ref) => completer.future),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: _SignInTrigger(onDialogShown: () {})),
      ),
    ));
    await tester.pump();

    await tester.tap(find.byKey(const Key('sign-in')));
    await tester.pump();
    await tester.pump(Duration.zero);

    expect(find.byKey(const Key('spinner')), findsOneWidget);

    completer.complete(false);
    await tester.pumpAndSettle();
  });

  testWidgets('hides spinner after successful sign-in', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pump();

    await tester.tap(find.byKey(const Key('sign-in')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('spinner')), findsNothing);
  });

  testWidgets('calls showFailureDialog on AuthLinkException', (tester) async {
    bool dialogShown = false;
    await tester.pumpWidget(_buildApp(throwOnLink: true, onDialogShown: () => dialogShown = true));
    await tester.pump();

    await tester.tap(find.byKey(const Key('sign-in')));
    await tester.pumpAndSettle();

    expect(dialogShown, isTrue);
  });

  testWidgets('hides spinner after AuthLinkException', (tester) async {
    await tester.pumpWidget(_buildApp(throwOnLink: true, onDialogShown: () {}));
    await tester.pump();

    await tester.tap(find.byKey(const Key('sign-in')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('spinner')), findsNothing);
  });
}
