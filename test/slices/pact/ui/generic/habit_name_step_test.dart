import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/habit_name_step.dart';

final _today = DateTime(2026, 1, 1);

Widget _wrap(
  PactCreationState state, {
  bool showCommitmentWarning = false,
  FocusNode? focusNode,
  ValueChanged<String>? onHabitNameChanged,
  Widget Function(BuildContext, AppLocalizations, TextEditingController, FocusNode?)? buildField,
  Widget Function(BuildContext, AppLocalizations)? buildWarning,
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
      body: Builder(builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return HabitNameStep(
          state: state,
          l10n: l10n,
          onHabitNameChanged: onHabitNameChanged ?? (_) {},
          showCommitmentWarning: showCommitmentWarning,
          focusNode: focusNode,
          buildField: buildField ??
              (ctx, l10n, controller, fn) => TextField(
                    key: const Key('test-field'),
                    controller: controller,
                    focusNode: fn,
                    onChanged: onHabitNameChanged,
                  ),
          buildWarning: buildWarning,
        );
      }),
    ),
  );
}

void main() {
  testWidgets('renders buildField widget', (tester) async {
    await tester.pumpWidget(_wrap(PactCreationState(today: _today)));
    expect(find.byKey(const Key('test-field')), findsOneWidget);
  });

  testWidgets('renders buildWarning when showCommitmentWarning is true', (tester) async {
    await tester.pumpWidget(_wrap(
      PactCreationState(today: _today),
      showCommitmentWarning: true,
      buildWarning: (_, __) => const Text('Warning text'),
    ));
    expect(find.text('Warning text'), findsOneWidget);
  });

  testWidgets('does not render buildWarning when showCommitmentWarning is false', (tester) async {
    await tester.pumpWidget(_wrap(
      PactCreationState(today: _today),
      showCommitmentWarning: false,
      buildWarning: (_, __) => const Text('Warning text'),
    ));
    expect(find.text('Warning text'), findsNothing);
  });

  testWidgets('controller text matches state.habitName', (tester) async {
    late TextEditingController capturedController;
    final state = PactCreationState(
      today: _today,
      builder: PactCreationState(today: _today).builder.copyWith(habitName: 'Yoga'),
    );
    await tester.pumpWidget(_wrap(
      state,
      buildField: (ctx, l10n, controller, fn) {
        capturedController = controller;
        return TextField(key: const Key('test-field'), controller: controller);
      },
    ));
    expect(capturedController.text, 'Yoga');
  });

  testWidgets('passes FocusNode to buildField', (tester) async {
    final focusNode = FocusNode();
    FocusNode? receivedNode;
    await tester.pumpWidget(_wrap(
      PactCreationState(today: _today),
      focusNode: focusNode,
      buildField: (ctx, l10n, controller, fn) {
        receivedNode = fn;
        return const SizedBox();
      },
    ));
    expect(receivedNode, focusNode);
    focusNode.dispose();
  });

  testWidgets('renders habitNameLabel from l10n', (tester) async {
    await tester.pumpWidget(_wrap(PactCreationState(today: _today)));
    // The label text is rendered in the step; AppLocalizations provides it.
    final l10nWidgets = find.descendant(of: find.byType(HabitNameStep), matching: find.byType(Text));
    expect(l10nWidgets, findsAtLeastNWidgets(1));
  });
}
