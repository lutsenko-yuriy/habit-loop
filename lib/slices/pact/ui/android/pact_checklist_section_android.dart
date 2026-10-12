import 'package:flutter/material.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_checklist_section_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_checklist_tile_switcher.dart';
import 'package:habit_loop/theme/spacing.dart';
import 'package:habit_loop/theme/widgets/section_header.dart';

/// Pact-detail "Checklist" section (GH #464). Presentational: state in, callbacks out.
class PactChecklistSectionAndroid extends StatelessWidget {
  const PactChecklistSectionAndroid({
    super.key,
    required this.state,
    required this.onSelect,
    required this.onChange,
    required this.onRemove,
  });

  final PactChecklistSectionState state;
  final VoidCallback onSelect;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (!state.isLoaded) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final link = state.link;
    final error = state.error;
    final theme = Theme.of(context);
    final compact = TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
    );
    return Column(
      key: const Key('pact-checklist-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.pactChecklistSectionTitle, labelColor: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: AppSpacing.s8),
        PactChecklistTileSwitcher(
          child: link == null
              ? _ChecklistRow(
                  key: const Key('pact-checklist-empty'),
                  label: l10n.pactChecklistEmpty,
                  labelColor: theme.colorScheme.onSurfaceVariant,
                  trailing: TextButton(
                    key: const Key('pact-checklist-select-button'),
                    style: compact,
                    onPressed: onSelect,
                    child: Text(l10n.pactChecklistSelect),
                  ),
                )
              : _ChecklistRow(
                  key: ValueKey('pact-checklist-linked:${link.checklistId}'),
                  label: link.checklistName,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        key: const Key('pact-checklist-change-button'),
                        style: compact,
                        onPressed: onChange,
                        child: Text(l10n.pactChecklistChange),
                      ),
                      TextButton(
                        key: const Key('pact-checklist-remove-button'),
                        style: compact.copyWith(foregroundColor: WidgetStatePropertyAll(theme.colorScheme.error)),
                        onPressed: onRemove,
                        child: Text(l10n.pactChecklistRemove),
                      ),
                    ],
                  ),
                ),
        ),
        if (error != null)
          Text(
            error == PactChecklistSectionError.noChecklists
                ? l10n.pactChecklistNoChecklistsError
                : l10n.checklisterCouldNotOpenError,
            key: const Key('pact-checklist-error'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}

/// Label on the left (default text style, like the Timeline rows), actions on the right.
class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({super.key, required this.label, this.labelColor, required this.trailing});

  final String label;
  final Color? labelColor;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: labelColor != null ? TextStyle(color: labelColor) : null)),
        const SizedBox(width: AppSpacing.s8),
        trailing,
      ],
    );
  }
}
