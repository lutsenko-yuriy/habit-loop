import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/android/pact_break_creation_page_android.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_break_creation_state.dart';

final _state = PactBreakCreationState(
  startDate: DateTime(2026, 6, 15),
  endDate: DateTime(2026, 6, 22),
);

Widget _buildApp(
  PactBreakCreationState state, {
  ValueChanged<DateTime>? onStartDateChanged,
  ValueChanged<DateTime>? onEndDateChanged,
  ValueChanged<bool>? onUntilPactEndsChanged,
  ValueChanged<String>? onRationaleChanged,
  VoidCallback? onSubmit,
  VoidCallback? onClose,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: PactBreakCreationPageAndroid(
      state: state,
      onStartDateChanged: onStartDateChanged ?? (_) {},
      onEndDateChanged: onEndDateChanged ?? (_) {},
      onUntilPactEndsChanged: onUntilPactEndsChanged ?? (_) {},
      onRationaleChanged: onRationaleChanged ?? (_) {},
      onSubmit: onSubmit ?? () {},
      onClose: onClose ?? () {},
    ),
  );
}

void main() {
  group('PactBreakCreationPageAndroid', () {
    testWidgets('shows end date row by default (fixed end)', (tester) async {
      await tester.pumpWidget(_buildApp(_state));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('break-end-date-row')), findsOneWidget);
    });

    testWidgets('hides end date row when untilPactEnds is true', (tester) async {
      await tester.pumpWidget(_buildApp(_state.copyWith(untilPactEnds: true)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('break-end-date-row')), findsNothing);
    });

    testWidgets('hides the next-showup hint when there is none (HAB-215)', (tester) async {
      await tester.pumpWidget(_buildApp(_state));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('break-next-showup-hint')), findsNothing);
    });

    testWidgets('shows the next-showup hint once nextShowupAfterEnd resolves (HAB-215)', (tester) async {
      await tester.pumpWidget(_buildApp(_state.copyWith(showupScheduledDates: [DateTime(2026, 6, 24, 8)])));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('break-next-showup-hint')), findsOneWidget);
    });

    testWidgets('toggling the switch calls onUntilPactEndsChanged', (tester) async {
      bool? toggled;
      await tester.pumpWidget(_buildApp(_state, onUntilPactEndsChanged: (v) => toggled = v));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('break-until-pact-ends-switch')));
      expect(toggled, true);
    });

    testWidgets('submit button is disabled when rationale is empty', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_buildApp(_state, onSubmit: () => tapped = true));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('break-submit-button')));
      expect(tapped, false);
    });

    testWidgets('submit button calls onSubmit when rationale is set', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _buildApp(_state.copyWith(rationale: 'Feeling sick'), onSubmit: () => tapped = true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('break-submit-button')));
      expect(tapped, true);
    });

    testWidgets('typing in the rationale field calls onRationaleChanged', (tester) async {
      String? typed;
      await tester.pumpWidget(_buildApp(_state, onRationaleChanged: (v) => typed = v));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('break-rationale-field')), 'Travel');
      expect(typed, 'Travel');
    });

    testWidgets('shows activity indicator instead of submit label when isSubmitting', (tester) async {
      await tester.pumpWidget(_buildApp(_state.copyWith(rationale: 'x', isSubmitting: true)));
      await tester.pump(); // avoid pumpAndSettle — the indicator animates indefinitely
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error text when submitError is set', (tester) async {
      await tester.pumpWidget(_buildApp(_state.copyWith(submitError: Exception('boom'))));
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.startBreakError), findsOneWidget);
    });

    testWidgets('tapping close calls onClose', (tester) async {
      bool closed = false;
      await tester.pumpWidget(_buildApp(_state, onClose: () => closed = true));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('break-close-button')));
      expect(closed, true);
    });
  });
}
