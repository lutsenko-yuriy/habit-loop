import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/generic/section_header.dart';
import 'package:habit_loop/slices/pact/ui/generic/status_badge.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_content.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_state.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_status_colors.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_ui_state.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Slot builders (deterministic test doubles)
// ---------------------------------------------------------------------------

ShowupDetailSlots _slots({
  String actionKey = 'action-buttons',
  String noteFieldKey = 'note-field',
  String saveKey = 'save-button',
  String errorKey = 'error-container',
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
    );

// ---------------------------------------------------------------------------
// Wrap helper
// ---------------------------------------------------------------------------

Widget _wrap(
  ShowupDetailState state, {
  VoidCallback? onOpenPact,
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
          onOpenPact: onOpenPact,
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

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
}
