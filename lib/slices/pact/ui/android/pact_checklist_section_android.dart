import 'package:flutter/material.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_checklist_section_state.dart';
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
    return Column(
      key: const Key('pact-checklist-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
            title: l10n.pactChecklistSectionTitle, labelColor: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: AppSpacing.s8),
        if (link == null)
          TextButton(
            key: const Key('pact-checklist-select-button'),
            onPressed: onSelect,
            child: Text(l10n.pactChecklistSelect),
          )
        else ...[
          Text(link.checklistName, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                key: const Key('pact-checklist-change-button'),
                onPressed: onChange,
                child: Text(l10n.pactChecklistChange),
              ),
              TextButton(
                key: const Key('pact-checklist-remove-button'),
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                onPressed: onRemove,
                child: Text(l10n.pactChecklistRemove),
              ),
            ],
          ),
        ],
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
