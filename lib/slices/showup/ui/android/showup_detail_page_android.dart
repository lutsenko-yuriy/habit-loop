import 'package:flutter/material.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_content.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_state.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_status_colors.dart';
import 'package:habit_loop/theme/spacing.dart';
import 'package:habit_loop/theme/typography.dart';

/// Material (Android) implementation of the showup detail screen.
class ShowupDetailPageAndroid extends StatelessWidget {
  final ShowupDetailState state;
  final Future<void> Function() onMarkDone;
  final Future<void> Function() onMarkFailed;
  final Future<void> Function(String note) onSaveNote;
  final Future<void> Function() onRedeemShowup;

  /// Called when the user taps the habit name to open the parent pact detail.
  /// Null when the pact has been deleted (habitName is also null in that case).
  final VoidCallback? onOpenPact;

  const ShowupDetailPageAndroid({
    super.key,
    required this.state,
    required this.onMarkDone,
    required this.onMarkFailed,
    required this.onSaveNote,
    required this.onRedeemShowup,
    this.onOpenPact,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = ShowupStatusColors.material(theme.colorScheme);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(scrolledUnderElevation: 0, title: Text(l10n.showupDetailTitle)),
      body: Column(
        children: [
          Container(height: 0.5, color: theme.dividerColor),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.isShowupNotFound
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l10n.showupNotFound, textAlign: TextAlign.center),
                            const SizedBox(height: AppSpacing.s16),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(l10n.back),
                            ),
                          ],
                        ),
                      )
                    : state.loadError != null
                        ? Center(child: Text(state.loadError.toString()))
                        : ShowupDetailContent(
                            state: state,
                            l10n: l10n,
                            onSaveNote: onSaveNote,
                            onRedeemShowup: onRedeemShowup,
                            onOpenPact: onOpenPact,
                            statusColors: colors,
                            labelColor: theme.colorScheme.onSurfaceVariant,
                            tileColor: theme.colorScheme.surfaceContainerHighest,
                            linkColor: theme.colorScheme.primary,
                            bottomPadding: bottomPadding,
                            slots: (
                              buildActionButtons: (ctx, s) => Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      FilledButton(
                                        onPressed: s.isSaving ? null : onMarkDone,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: theme.colorScheme.secondary,
                                        ),
                                        child: s.isSaving
                                            ? const SizedBox(
                                                height: AppSpacing.s20,
                                                width: AppSpacing.s20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Text(l10n.markDone),
                                      ),
                                      const SizedBox(height: AppSpacing.s8),
                                      OutlinedButton(
                                        onPressed: s.isSaving ? null : onMarkFailed,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: theme.colorScheme.error,
                                        ),
                                        child: Text(l10n.markFailed),
                                      ),
                                    ],
                                  ),
                              buildNoteField: (ctx, ctrl) => TextField(
                                    key: const Key('showup-note-field'),
                                    controller: ctrl,
                                    maxLines: 4,
                                    decoration: InputDecoration(
                                      border: const OutlineInputBorder(),
                                      hintText: l10n.showupNoteLabel,
                                    ),
                                  ),
                              buildSaveButton: (ctx, onPressed) => FilledButton.tonal(
                                    key: const Key('showup-note-save-button'),
                                    onPressed: onPressed,
                                    child: Text(l10n.showupNoteSave),
                                  ),
                              buildErrorContainer: (ctx) => Card(
                                    color: theme.colorScheme.errorContainer,
                                    margin: EdgeInsets.zero,
                                    child: Padding(
                                      padding: const EdgeInsets.all(AppSpacing.s12),
                                      child: Text(
                                        l10n.showupAutoFailed,
                                        style: TextStyle(color: theme.colorScheme.onErrorContainer),
                                      ),
                                    ),
                                  ),
                              buildRedemptionButton: (ctx, onRedeem) => FilledButton(
                                    key: const Key('showup-redeem-button'),
                                    onPressed: onRedeem,
                                    child: Text(l10n.showupRedeemAction),
                                  ),
                              buildRedemptionHint: (ctx) => Text(
                                    l10n.showupRedeemAddNoteHint,
                                    style: AppTypography.caption.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    textAlign: TextAlign.center,
                                  ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
