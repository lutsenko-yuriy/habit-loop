import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_content.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_state.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_status_colors.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_ui_state.dart';
import 'package:habit_loop/theme/widgets/section_header.dart';
import 'package:habit_loop/theme/widgets/status_badge.dart';

// Fixtures

Showup _showup({ShowupStatus status = ShowupStatus.pending, String? note}) => Showup(
      id: 'su-1',
      pactId: 'p-1',
      scheduledAt: DateTime(2026, 6, 7, 9, 0),
      duration: const Duration(minutes: 30),
      status: status,
      note: note,
    );

ShowupDetailState _loadedState({
  ShowupStatus status = ShowupStatus.pending,
  String? note,
  bool isSaving = false,
  Object? markError,
  Object? noteError,
  bool wasAutoFailed = false,
  String? habitName = 'Meditate',
  ShowupUiState uiState = ShowupUiState.planned,
}) =>
    ShowupDetailState(
      showup: _showup(status: status, note: note),
      habitName: habitName,
      uiState: uiState,
      isLoading: false,
      isSaving: isSaving,
      markError: markError,
      noteError: noteError,
      wasAutoFailed: wasAutoFailed,
    );

// Slot builders (deterministic test doubles)

ShowupDetailSlots _slots({
  String actionKey = 'action-buttons',
  String noteFieldKey = 'note-field',
  String saveKey = 'save-button',
  String errorKey = 'error-container',
  String redeemKey = 'redeem-button',
  String redeemHintKey = 'redeem-hint',
  String startBreakKey = 'start-break-button',
  VoidCallback? onSavePressed,
}) =>
    (
      buildActionButtons: (ctx, s) => SizedBox(key: Key(actionKey)),
      buildNoteField: (ctx, ctrl) => TextField(key: Key(noteFieldKey), controller: ctrl),
      buildSaveButton: (ctx, onPressed) {
        if (onSavePressed != null && onPressed != null) onSavePressed();
        return TextButton(key: Key(saveKey), onPressed: onPressed, child: const Text('Save'));
      },
      buildErrorContainer: (ctx) => SizedBox(key: Key(errorKey)),
      buildRedemptionButton: (ctx, onRedeem) => TextButton(
            key: Key(redeemKey),
            onPressed: onRedeem,
            child: const Text('Redeem'),
          ),
      buildRedemptionHint: (ctx) => SizedBox(key: Key(redeemHintKey)),
      buildStartBreakButton: (ctx, onPressed) => TextButton(
            key: Key(startBreakKey),
            onPressed: onPressed,
            child: const Text('Take a Break'),
          ),
    );

// Wrap helper

Widget _wrap(
  ShowupDetailState state, {
  VoidCallback? onOpenPact,
  VoidCallback? onStartBreak,
  ShowupDetailSlots? slots,
  Future<void> Function(String)? onSaveNote,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => ShowupDetailContent(
          state: state,
          l10n: AppLocalizations.of(context)!,
          onSaveNote: onSaveNote ?? (_) async {},
          onRedeemShowup: () async {},
          onOpenPact: onOpenPact,
          onStartBreak: onStartBreak,
          statusColors: ShowupStatusColors.material(Theme.of(context).colorScheme),
          labelColor: Colors.grey,
          tileColor: Colors.grey.shade100,
          linkColor: Colors.blue,
          slots: slots ?? _slots(),
        ),
      ),
    ),
  );
}

// Tests

void main() {
  group('ShowupDetailContent — controller lifecycle', () {
    testWidgets('initializes note controller with state note', (tester) async {
      final state = _loadedState(note: 'Morning run');
      await tester.pumpWidget(_wrap(state));
      await tester.pump();
      final field = tester.widget<TextField>(find.byKey(const Key('note-field')));
      expect(field.controller!.text, 'Morning run');
    });

    testWidgets('initializes controller to empty string when note is null', (tester) async {
      final state = _loadedState();
      await tester.pumpWidget(_wrap(state));
      await tester.pump();
      final field = tester.widget<TextField>(find.byKey(const Key('note-field')));
      expect(field.controller!.text, '');
    });
  });

  group('ShowupDetailContent — habit name + status', () {
    testWidgets('renders habit name', (tester) async {
      await tester.pumpWidget(_wrap(_loadedState(habitName: 'Meditate')));
      await tester.pump();
      expect(find.text('Meditate'), findsOneWidget);
    });

    testWidgets('renders StatusBadge', (tester) async {
      await tester.pumpWidget(_wrap(_loadedState()));
      await tester.pump();
      expect(find.byType(StatusBadge), findsOneWidget);
    });
  });

  group('ShowupDetailContent — pact link', () {
    testWidgets('shows pact link when onOpenPact is provided', (tester) async {
      await tester.pumpWidget(_wrap(_loadedState(), onOpenPact: () {}));
      await tester.pump();
      expect(find.byKey(const Key('showup-pact-link')), findsOneWidget);
    });

    testWidgets('hides pact link when onOpenPact is null', (tester) async {
      await tester.pumpWidget(_wrap(_loadedState()));
      await tester.pump();
      expect(find.byKey(const Key('showup-pact-link')), findsNothing);
    });
  });

  group('ShowupDetailContent — start break button', () {
    testWidgets('shows start break button when onStartBreak is provided', (tester) async {
      await tester.pumpWidget(_wrap(_loadedState(), onStartBreak: () {}));
      await tester.pump();
      expect(find.byKey(const Key('start-break-button')), findsOneWidget);
    });

    testWidgets('hides start break button when onStartBreak is null', (tester) async {
      await tester.pumpWidget(_wrap(_loadedState()));
      await tester.pump();
      expect(find.byKey(const Key('start-break-button')), findsNothing);
    });
  });

  group('ShowupDetailContent — action buttons slot', () {
    testWidgets('calls buildActionButtons when isPending', (tester) async {
      final state = _loadedState(status: ShowupStatus.pending);
      await tester.pumpWidget(_wrap(state));
      await tester.pump();
      expect(find.byKey(const Key('action-buttons')), findsOneWidget);
    });

    testWidgets('does not call buildActionButtons when not pending', (tester) async {
      final state = _loadedState(status: ShowupStatus.done);
      await tester.pumpWidget(_wrap(state));
      await tester.pump();
      expect(find.byKey(const Key('action-buttons')), findsNothing);
    });

    // HAB-213 WU2: on break, the "On break" badge alone carries the state —
    // Mark Done/Failed would be misleading actions, so they're hidden entirely.
    testWidgets('does not call buildActionButtons when pending but on break', (tester) async {
      final state = _loadedState(status: ShowupStatus.pending, uiState: ShowupUiState.onBreak);
      await tester.pumpWidget(_wrap(state));
      await tester.pump();
      expect(find.byKey(const Key('action-buttons')), findsNothing);
    });
  });

  group('ShowupDetailContent — note field + save button slots', () {
    testWidgets('renders buildNoteField slot', (tester) async {
      await tester.pumpWidget(_wrap(_loadedState()));
      await tester.pump();
      expect(find.byKey(const Key('note-field')), findsOneWidget);
    });

    testWidgets('renders buildSaveButton slot', (tester) async {
      await tester.pumpWidget(_wrap(_loadedState()));
      await tester.pump();
      expect(find.byKey(const Key('save-button')), findsOneWidget);
    });

    testWidgets('save button receives null onPressed when note unchanged', (tester) async {
      final state = _loadedState(note: 'Same');
      await tester.pumpWidget(_wrap(state));
      await tester.pump();
      final btn = tester.widget<TextButton>(find.byKey(const Key('save-button')));
      expect(btn.onPressed, isNull);
    });
  });

  group('ShowupDetailContent — error container slot', () {
    testWidgets('calls buildErrorContainer when wasAutoFailed', (tester) async {
      final state = _loadedState(wasAutoFailed: true);
      await tester.pumpWidget(_wrap(state));
      await tester.pump();
      expect(find.byKey(const Key('error-container')), findsOneWidget);
    });

    testWidgets('does not call buildErrorContainer when not wasAutoFailed', (tester) async {
      final state = _loadedState(wasAutoFailed: false);
      await tester.pumpWidget(_wrap(state));
      await tester.pump();
      expect(find.byKey(const Key('error-container')), findsNothing);
    });
  });

  group('ShowupDetailContent — section header', () {
    testWidgets('renders SectionHeader for note label', (tester) async {
      await tester.pumpWidget(_wrap(_loadedState()));
      await tester.pump();
      expect(find.byType(SectionHeader), findsOneWidget);
    });
  });

  group('ShowupDetailContent — status badge animation (HAB-213 WU3)', () {
    testWidgets('crossfades badge text mid-transition, then settles to the new state', (tester) async {
      await tester.pumpWidget(_wrap(_loadedState(uiState: ShowupUiState.planned)));
      await tester.pump();
      expect(find.text('Planned'), findsOneWidget);

      await tester.pumpWidget(_wrap(_loadedState(uiState: ShowupUiState.onBreak)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));
      // Both outgoing and incoming labels are on screen mid-crossfade.
      expect(find.text('Planned'), findsOneWidget);
      expect(find.text('On break'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Planned'), findsNothing);
      expect(find.text('On break'), findsOneWidget);
    });
  });

  group('ShowupDetailContent — reveal animations (HAB-213 WU3)', () {
    testWidgets('action buttons fade out through AnimatedReveal when isPending flips to false', (tester) async {
      await tester.pumpWidget(_wrap(_loadedState(status: ShowupStatus.pending)));
      await tester.pump();
      expect(find.byKey(const Key('action-buttons')), findsOneWidget);

      await tester.pumpWidget(_wrap(_loadedState(status: ShowupStatus.done)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));
      final opacity = tester.widget<Opacity>(
        find.ancestor(of: find.byKey(const Key('action-buttons')), matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, greaterThan(0));
      expect(opacity.opacity, lessThan(1));

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('action-buttons')), findsNothing);
    });

    testWidgets('pact link row fades in through AnimatedReveal when onOpenPact becomes non-null', (tester) async {
      final state = _loadedState();
      await tester.pumpWidget(_wrap(state));
      await tester.pump();
      expect(find.byKey(const Key('showup-pact-link')), findsNothing);

      await tester.pumpWidget(_wrap(state, onOpenPact: () {}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));
      final opacity = tester.widget<Opacity>(
        find.ancestor(of: find.byKey(const Key('showup-pact-link')), matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, greaterThan(0));
      expect(opacity.opacity, lessThan(1));

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('showup-pact-link')), findsOneWidget);
    });
  });
}
