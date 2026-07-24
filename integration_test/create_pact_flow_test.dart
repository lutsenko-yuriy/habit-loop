// On-device entry point for the create-pact flow test.
//
// Run with: flutter test integration_test/create_pact_flow_test.dart -d <device>
// Run on host: flutter test integration_test/create_pact_flow_test.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart' show todayProvider;
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_view_model.dart';
import 'package:integration_test/integration_test.dart';

import '../test/infrastructure/remote_config/fake_remote_config_service.dart';
import 'harness.dart';

// Fixed clock, 5 minutes before the wizard's default Mon-Fri 08:00 slot, so
// today's showup is guaranteed to still be in the future regardless of the
// real wall-clock time the suite happens to run at. Same value used by
// edit_pact_flow_test.dart and pact_timeline_flow_test.dart. All three
// "now" providers touched by pact creation must agree, or the wizard's
// default start date, the submit-time eligibility check, and the
// dashboard's own calendar strip end up reasoning about different days.
final _testNow = DateTime(2099, 6, 15, 7, 55);

/// Swipes the pact-creation [PageView] to the next page.
///
/// Starts near the **top-right** of the PageView (the static title area) so
/// that interactive widgets lower on the page — in particular the [Slider] on
/// the showup-duration step — cannot intercept the gesture.
///
/// Uses 300 px / 50 ms (timedDragFrom) instead of flingFrom(-400, 1000):
/// - 300 px keeps the pointer on-screen for any ≥310 dp device
///   (start x = right-10 = ~380; end x = ~80, within the viewport).
///   flingFrom(-400) from x=380 went to x=-20, which was off-screen.
/// - (300/W)+0.5 rounds to 1 for any W≥300 dp, so no page overshoot.
///
/// Tries the iOS key first, falls back to the Android key.
Future<void> _swipeWizardForward(WidgetTester tester) async {
  const iosKey = Key('pact-creation-pageview-ios');
  const androidKey = Key('pact-creation-pageview-android');
  final key = find.byKey(iosKey).evaluate().isNotEmpty ? iosKey : androidKey;
  final rect = tester.getRect(find.byKey(key));
  // Y = top + 40: safely inside the title text area on every wizard page.
  await tester.timedDragFrom(
    Offset(rect.right - 10, rect.top + 40),
    const Offset(-300, 0),
    const Duration(milliseconds: 50),
  );
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Create pact flow', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets(
        'full_wizard_creates_pact: completing all wizard steps creates a pact, shows today\'s showup, and fires pact_created',
        (tester) async {
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
          pactCreationTodayProvider.overrideWithValue(_testNow),
          pactCreationSubmitNowProvider.overrideWithValue(() => _testNow),
          todayProvider.overrideWithValue(_testNow),
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
      // A plain pump() (not pumpAndSettle()) — the cursor blink animation
      // never settles. The extra 300ms pump lets the keyboard-show animation
      // catch up so the first _swipeWizardForward's getRect() below reads a
      // stable PageView rect instead of one still mid-resize.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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

      // ── 10. Wait for submit() to actually finish ──────────────────────────
      // The Summary step (still on screen at this point) already renders the
      // habit name as a summary row value, so a plain waitFor(find.text(
      // 'Meditate')) matches it immediately — before submit() completes and
      // pops the wizard — rather than proving the dashboard shows the new
      // pact. Wait for the pact_created event (fired at the very end of
      // submit(), after the cache write-through added in HAB-174 WU2) so the
      // wizard is guaranteed to have popped before we assert on the dashboard.
      final deadline = tester.binding.clock.now().add(const Duration(seconds: 30));
      while (!h.analytics.loggedEvents.any((e) => e.name == 'pact_created')) {
        if (tester.binding.clock.now().isAfter(deadline)) {
          throw TestFailure('pact_created event was not fired within the timeout');
        }
        await tester.pump(const Duration(milliseconds: 100));
      }

      // ── 11. Dashboard shows pact name and today's showup ─────────────────
      // ignore: avoid_print
      print('DIAG pact_created observed, starting waitFor(Meditate) at ${DateTime.now().toIso8601String()}');
      // Inlined waitFor with periodic progress prints (HAB-196 diagnostic):
      // reveals whether tester.pump() itself is returning during the stall,
      // or whether it's the widget tree that never rebuilds.
      final waitDeadline = tester.binding.clock.now().add(const Duration(seconds: 60));
      var diagIteration = 0;
      while (find.text('Meditate').evaluate().isEmpty) {
        if (tester.binding.clock.now().isAfter(waitDeadline)) {
          // ignore: avoid_print
          print('DIAG waitFor(Meditate) giving up at iteration $diagIteration, ${DateTime.now().toIso8601String()}');
          throw TestFailure('waitFor timed out: ${find.text('Meditate')}');
        }
        diagIteration++;
        if (diagIteration % 10 == 0) {
          // ignore: avoid_print
          print('DIAG waitFor(Meditate) iteration $diagIteration at ${DateTime.now().toIso8601String()}');
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
      // At least one showup tile is present for the current day.
      expect(find.text('Meditate'), findsWidgets);
    });
  });
}
