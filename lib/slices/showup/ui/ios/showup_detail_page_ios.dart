import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType, Theme;
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_content.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_state.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_status_colors.dart';
import 'package:habit_loop/theme/colors.dart';
import 'package:habit_loop/theme/spacing.dart';

/// Cupertino (iOS) implementation of the showup detail screen.
class ShowupDetailPageIos extends StatelessWidget {
  final ShowupDetailState state;
  final Future<void> Function() onMarkDone;
  final Future<void> Function() onMarkFailed;
  final Future<void> Function(String note) onSaveNote;
  final Future<void> Function() onRedeemShowup;

  /// Called when the user taps the habit name to open the parent pact detail.
  /// Null when the pact has been deleted (habitName is also null in that case).
  final VoidCallback? onOpenPact;

  const ShowupDetailPageIos({
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
    final colors = ShowupStatusColors.cupertino(context);
    final labelColor = CupertinoColors.systemGrey.resolveFrom(context);
    final tileColor = CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final linkColor = CupertinoColors.activeBlue.resolveFrom(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        middle: Text(l10n.showupDetailTitle),
      ),
      child: SafeArea(
        bottom: false,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              Container(height: 0.5, color: CupertinoColors.separator.resolveFrom(context)),
              Expanded(
                child: state.isLoading
                    ? const Center(child: CupertinoActivityIndicator())
                    : state.isShowupNotFound
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(l10n.showupNotFound, textAlign: TextAlign.center),
                                const SizedBox(height: AppSpacing.s16),
                                CupertinoButton(
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
                                labelColor: labelColor,
                                tileColor: tileColor,
                                linkColor: linkColor,
                                bottomPadding: bottomPadding,
                                slots: (
                                  buildActionButtons: (ctx, s) => Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          CupertinoButton.filled(
                                            onPressed: s.isSaving ? null : onMarkDone,
                                            child: s.isSaving
                                                ? const CupertinoActivityIndicator(color: Colors.white)
                                                : Text(l10n.markDone),
                                          ),
                                          const SizedBox(height: AppSpacing.s8),
                                          CupertinoButton(
                                            onPressed: s.isSaving ? null : onMarkFailed,
                                            child: Text(
                                              l10n.markFailed,
                                              style: TextStyle(color: CupertinoColors.destructiveRed.resolveFrom(ctx)),
                                            ),
                                          ),
                                        ],
                                      ),
                                  buildNoteField: (ctx, ctrl) => CupertinoTextField(
                                        key: const Key('showup-note-field'),
                                        controller: ctrl,
                                        placeholder: l10n.showupNoteLabel,
                                        maxLines: 4,
                                        minLines: 2,
                                        padding: const EdgeInsets.all(AppSpacing.s12),
                                      ),
                                  buildSaveButton: (ctx, onPressed) => CupertinoButton(
                                        key: const Key('showup-note-save-button'),
                                        onPressed: onPressed,
                                        child: Text(l10n.showupNoteSave),
                                      ),
                                  buildErrorContainer: (ctx) => Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(AppSpacing.s12),
                                        decoration: BoxDecoration(
                                          color: HabitLoopColors.danger.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: HabitLoopColors.danger.withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: Text(
                                          l10n.showupAutoFailed,
                                          style: TextStyle(
                                            color: CupertinoColors.destructiveRed.resolveFrom(ctx),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                  buildRedemptionButton: (ctx, onRedeem) => CupertinoButton.filled(
                                        key: const Key('showup-redeem-button'),
                                        onPressed: onRedeem,
                                        child: Text(l10n.showupRedeemAction),
                                      ),
                                  buildRedemptionHint: (ctx) => Text(
                                        l10n.showupRedeemAddNoteHint,
                                        style: const TextStyle(
                                          color: CupertinoColors.systemGrey,
                                          fontSize: 13,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
