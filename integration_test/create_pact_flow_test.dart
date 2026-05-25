// On-device entry point for the create-pact flow test.
//
// Run with: flutter test integration_test/create_pact_flow_test.dart -d <device>
// Run on host: flutter test integration_test/create_pact_flow_test.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:integration_test/integration_test.dart';

import '../test/infrastructure/remote_config/fake_remote_config_service.dart';
import 'harness.dart';

/// Swipes the pact-creation [PageView] to the next page.
///
/// Starts the fling from near the **top** of the PageView (the static title
/// area) so that interactive widgets lower on the page — in particular the
/// [Slider] on the showup-duration step — cannot intercept the horizontal
/// gesture and win the gesture arena before the PageView does.
///
/// Tries the iOS key first, falls back to the Android key, so the same test
/// runs on both platforms without modification.
Future<void> _swipeWizardForward(WidgetTester tester) async {
  const iosKey = Key('pact-creation-pageview-ios');
  const androidKey = Key('pact-creation-pageview-android');
  final key = find.byKey(iosKey).evaluate().isNotEmpty ? iosKey : androidKey;
  final rect = tester.getRect(find.byKey(key));
  // Y = top + 40: safely inside the title text area on every wizard page.
  await tester.flingFrom(Offset(rect.right - 10, rect.top + 40), const Offset(-400, 0), 1000);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Create pact flow', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('full wizard creates a pact and showup appears on dashboard', (tester) async {
      h = await AppHarness.create(
        tester,
        initiallyAnonymous: true,
        extraOverrides: [
          remoteConfigServiceProvider.overrideWithValue(
            FakeRemoteConfigService(overrides: {
              'onboarding_auto_advance_seconds': 0,
              // Use the 'button' variant (control) so the commitment dialog
              // shows a single "I Accept" button — simplest to automate.
              'exp_003_commitment_confirmation': 'button',
            }),
          ),
        ],
      );
      final strings = l10n(tester);

      // ── 1. Dashboard shows the onboarding carousel (no pacts yet) ────────
      expect(find.text(strings.onboardingSlide0Title), findsOneWidget);
      expect(find.text(strings.createPact), findsOneWidget);

      // ── 2. Open pact creation wizard ────────────────────────────────────
      await tester.tap(find.text(strings.createPact));
      await waitFor(tester, find.text(strings.pactCreationTitle));
      expect(find.text(strings.pactCreationTitle), findsOneWidget);

      // ── 3. Page 0 – habit name: enter text ──────────────────────────────
      // Platform-agnostic: Android uses TextField, iOS uses CupertinoTextField.
      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField || w is CupertinoTextField),
        'Meditate',
      );
      await tester.pump();

      // ── 4. Page 0 → 1: swipe to pact duration (defaults are valid) ────────
      await _swipeWizardForward(tester);

      // ── 5. Page 1 → 2: swipe to showup duration (auto-set to 10 min) ─────
      await _swipeWizardForward(tester);

      // ── 6. Page 2 → 3: swipe to schedule ────────────────────────────────
      // NOTE: must start from the top of the PageView — the Slider on the
      // showup-duration page intercepts horizontal flings from the center.
      await _swipeWizardForward(tester);

      // ── 7. Page 3: schedule step — the slot-based editor is pre-selected
      // (Mon-Fri at 08:00 WeeklySlot) so no user interaction is needed here;
      // swipe directly to the reminder step.
      await _swipeWizardForward(tester);

      // ── 8. Page 4 → 5: swipe to summary ─────────────────────────────────
      await _swipeWizardForward(tester);

      // ── 9. Commitment dialog – tap "I Accept" (button variant) ──────────
      // The summary page's "Create Pact" button is labeled createPactConfirm.
      await tester.tap(find.text(strings.createPactConfirm));
      await tester.pumpAndSettle();

      // The commitment dialog is now visible; tap the accept button.
      await tester.tap(find.text(strings.commitmentAccept));
      // Do not pumpAndSettle here: after submit the wizard pops and the
      // dashboard reloads (isLoading = true → CircularProgressIndicator), which
      // blocks pumpAndSettle indefinitely. Let waitFor() below drive the pumps
      // until the new pact name appears on the dashboard.

      // ── 10. Dashboard shows pact name and today's showup ─────────────────
      await waitFor(tester, find.text('Meditate'));
      // At least one showup tile is present for the current day.
      expect(find.text('Meditate'), findsWidgets);

      // ── 11. pact_created analytics event was fired ───────────────────────
      expect(
        h.analytics.loggedEvents.any((e) => e.name == 'pact_created'),
        isTrue,
      );
    });
  });
}
