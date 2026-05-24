/// WU4 integration tests — card-based schedule step (ScheduleType.slot)
///
/// Verifies that:
/// - Both iOS and Android schedule steps render [SlotScheduleEditor] for
///   [ScheduleType.slot] instead of the legacy mode picker.
/// - The new-pact default (Mon–Fri at 08:00 WeeklySlot) is visible on screen.
/// - Adding a slot via the "add-monthly-slot" button fires [onScheduleChanged]
///   with the updated [SlotSchedule].
/// - The wizard view-model's initial state already has [ScheduleType.slot] and
///   a non-empty default schedule so that [isScheduleSet] is `true` from the
///   start (no required user action on the schedule step for a standard weekly
///   schedule).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/android/schedule_step_android.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_view_model.dart';
import 'package:habit_loop/slices/pact/ui/ios/schedule_step_ios.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [PactCreationState] pre-filled with a slot schedule (the same
/// default the view model installs on build).
PactCreationState _defaultSlotState() {
  final today = DateTime(2026, 3, 30);
  final base = PactCreationState(today: today);
  return base.copyWith(
    builder: base.builder.copyWith(
      scheduleType: ScheduleType.slot,
      schedule: SlotSchedule(slots: [
        WeeklySlot(weekdays: {1, 2, 3, 4, 5}, timeOfDay: const Duration(hours: 8)),
      ]),
    ),
  );
}

/// A wrapper that gets [AppLocalizations] from context and passes it to
/// [ScheduleStepIos].
class _IosStepWrapper extends StatelessWidget {
  final PactCreationState state;
  final ValueChanged<ScheduleType> onScheduleTypeChanged;
  final ValueChanged<ShowupSchedule> onScheduleChanged;

  const _IosStepWrapper({
    required this.state,
    required this.onScheduleTypeChanged,
    required this.onScheduleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ScheduleStepIos(
      state: state,
      l10n: l10n,
      onScheduleTypeChanged: onScheduleTypeChanged,
      onScheduleChanged: onScheduleChanged,
    );
  }
}

/// A wrapper that gets [AppLocalizations] from context and passes it to
/// [ScheduleStepAndroid].
class _AndroidStepWrapper extends StatelessWidget {
  final PactCreationState state;
  final ValueChanged<ScheduleType> onScheduleTypeChanged;
  final ValueChanged<ShowupSchedule> onScheduleChanged;

  const _AndroidStepWrapper({
    required this.state,
    required this.onScheduleTypeChanged,
    required this.onScheduleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ScheduleStepAndroid(
      state: state,
      l10n: l10n,
      onScheduleTypeChanged: onScheduleTypeChanged,
      onScheduleChanged: onScheduleChanged,
    );
  }
}

Widget _wrapIos(Widget child) {
  return CupertinoApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: CupertinoPageScaffold(
      child: SafeArea(child: child),
    ),
  );
}

Widget _wrapAndroid(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // iOS schedule step — slot mode
  // -------------------------------------------------------------------------

  group('ScheduleStepIos — slot mode', () {
    testWidgets('shows SlotScheduleEditor (add buttons visible) instead of mode picker', (tester) async {
      final state = _defaultSlotState();
      await tester.pumpWidget(_wrapIos(
        _IosStepWrapper(
          state: state,
          onScheduleTypeChanged: (_) {},
          onScheduleChanged: (_) {},
        ),
      ));
      await tester.pump();

      // The card editor's add buttons are visible (confirming SlotScheduleEditor
      // is rendered rather than the legacy mode picker).
      expect(find.byKey(const Key('add-weekly-slot')), findsOneWidget);
      expect(find.byKey(const Key('add-monthly-slot')), findsOneWidget);

      // The legacy mode picker options (e.g., "Every day") should NOT appear
      // since we are in slot mode.
      expect(find.text('Every day'), findsNothing);
    });

    testWidgets('default slot card is rendered and remove button is hidden (single card)', (tester) async {
      final state = _defaultSlotState();
      await tester.pumpWidget(_wrapIos(
        _IosStepWrapper(
          state: state,
          onScheduleTypeChanged: (_) {},
          onScheduleChanged: (_) {},
        ),
      ));
      await tester.pump();

      // The first (and only) slot card must be present.
      expect(find.byKey(const Key('slot-card-0')), findsOneWidget);
      // Only one card → remove button should be hidden.
      expect(find.byKey(const Key('remove-slot-0')), findsNothing);
    });

    testWidgets('tapping add-monthly-slot fires onScheduleChanged with new MonthlySlot appended', (tester) async {
      final state = _defaultSlotState();
      SlotSchedule? emitted;
      await tester.pumpWidget(_wrapIos(
        _IosStepWrapper(
          state: state,
          onScheduleTypeChanged: (_) {},
          onScheduleChanged: (s) {
            if (s is SlotSchedule) emitted = s;
          },
        ),
      ));
      await tester.pump();

      await tester.tap(find.byKey(const Key('add-monthly-slot')));
      await tester.pump();

      expect(emitted, isNotNull);
      expect(emitted!.slots.length, 2);
      expect(emitted!.slots[0], isA<WeeklySlot>());
      expect(emitted!.slots[1], isA<MonthlySlot>());
    });
  });

  // -------------------------------------------------------------------------
  // Android schedule step — slot mode
  // -------------------------------------------------------------------------

  group('ScheduleStepAndroid — slot mode', () {
    testWidgets('shows SlotScheduleEditor instead of mode picker', (tester) async {
      final state = _defaultSlotState();
      await tester.pumpWidget(_wrapAndroid(
        _AndroidStepWrapper(
          state: state,
          onScheduleTypeChanged: (_) {},
          onScheduleChanged: (_) {},
        ),
      ));
      await tester.pump();

      expect(find.byKey(const Key('add-weekly-slot')), findsOneWidget);
      expect(find.byKey(const Key('add-monthly-slot')), findsOneWidget);
      expect(find.text('Every day'), findsNothing);
    });

    testWidgets('tapping add-weekly-slot fires onScheduleChanged with new WeeklySlot appended', (tester) async {
      final state = _defaultSlotState();
      SlotSchedule? emitted;
      await tester.pumpWidget(_wrapAndroid(
        _AndroidStepWrapper(
          state: state,
          onScheduleTypeChanged: (_) {},
          onScheduleChanged: (s) {
            if (s is SlotSchedule) emitted = s;
          },
        ),
      ));
      await tester.pump();

      await tester.tap(find.byKey(const Key('add-weekly-slot')));
      await tester.pump();

      expect(emitted, isNotNull);
      expect(emitted!.slots.length, 2);
      expect(emitted!.slots[0], isA<WeeklySlot>());
      expect(emitted!.slots[1], isA<WeeklySlot>());
    });
  });

  // -------------------------------------------------------------------------
  // PactCreationViewModel initial state — slot is default
  // -------------------------------------------------------------------------

  group('PactCreationViewModel default slot schedule', () {
    test('initial state has ScheduleType.slot and a non-empty WeeklySlot', () {
      final container = ProviderContainer(
        overrides: [
          pactCreationTodayProvider.overrideWithValue(DateTime(2026, 3, 30)),
          pactCreationSubmitNowProvider.overrideWithValue(() => DateTime(2026, 3, 30)),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(pactCreationViewModelProvider);

      expect(state.scheduleType, ScheduleType.slot);
      expect(state.schedule, isA<SlotSchedule>());
      final sched = state.schedule as SlotSchedule;
      expect(sched.slots, isNotEmpty);
      expect(sched.slots.first, isA<WeeklySlot>());
      // The default covers Mon-Fri (weekdays 1-5).
      expect((sched.slots.first as WeeklySlot).weekdays, containsAll([1, 2, 3, 4, 5]));
    });

    test('isScheduleSet is true for the default slot schedule', () {
      final container = ProviderContainer(
        overrides: [
          pactCreationTodayProvider.overrideWithValue(DateTime(2026, 3, 30)),
          pactCreationSubmitNowProvider.overrideWithValue(() => DateTime(2026, 3, 30)),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(pactCreationViewModelProvider);
      expect(state.builder.isScheduleSet, isTrue);
    });
  });
}
