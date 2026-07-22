import 'package:flutter/widgets.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/theme/spacing.dart';
import 'package:habit_loop/theme/typography.dart';

class HabitNameStep extends StatefulWidget {
  final PactCreationState state;
  final AppLocalizations l10n;
  final ValueChanged<String> onHabitNameChanged;
  final bool showCommitmentWarning;
  final FocusNode? focusNode;
  final TextStyle? titleStyle;
  final Widget Function(BuildContext, AppLocalizations, TextEditingController, FocusNode?) buildField;
  final Widget Function(BuildContext, AppLocalizations)? buildWarning;

  const HabitNameStep({
    super.key,
    required this.state,
    required this.l10n,
    required this.onHabitNameChanged,
    required this.buildField,
    this.showCommitmentWarning = true,
    this.focusNode,
    this.titleStyle,
    this.buildWarning,
  });

  @override
  State<HabitNameStep> createState() => _HabitNameStepState();
}

class _HabitNameStepState extends State<HabitNameStep> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.habitName)
      ..selection = TextSelection.collapsed(offset: widget.state.habitName.length);
  }

  @override
  void didUpdateWidget(covariant HabitNameStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.habitName != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.state.habitName,
        selection: TextSelection.collapsed(offset: widget.state.habitName.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      children: [
        const SizedBox(height: AppSpacing.s16),
        Text(
          widget.l10n.habitNameLabel,
          style: widget.titleStyle ?? AppTypography.wizardStepTitle,
        ),
        const SizedBox(height: AppSpacing.s16),
        widget.buildField(context, widget.l10n, _controller, widget.focusNode),
        if (widget.showCommitmentWarning && widget.buildWarning != null) ...[
          const SizedBox(height: AppSpacing.s24),
          widget.buildWarning!(context, widget.l10n),
        ],
        const SizedBox(height: AppSpacing.s16),
      ],
    );
  }
}
