import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType, Theme;
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_content.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_state.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_status_colors.dart';

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

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        middle: Text(l10n.showupDetailTitle),
      ),
      child: SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: state.isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : state.isShowupNotFound
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.showupNotFound, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
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
                                    const SizedBox(height: 8),
                                    CupertinoButton(
                                      onPressed: s.isSaving ? null : onMarkFailed,
                                      child: Text(
                                        l10n.markFailed,
                                        style: const TextStyle(color: CupertinoColors.destructiveRed),
                                      ),
                                    ),
                                  ],
                                ),
                            buildNoteField: (ctx, ctrl) => CupertinoTextField(
                                  controller: ctrl,
                                  placeholder: l10n.showupNoteLabel,
                                  maxLines: 4,
                                  minLines: 2,
                                  padding: const EdgeInsets.all(12),
                                ),
                            buildSaveButton: (ctx, onPressed) => CupertinoButton(
                                  onPressed: onPressed,
                                  child: Text(l10n.showupNoteSave),
                                ),
                            buildErrorContainer: (ctx) => Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: CupertinoColors.systemRed.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    l10n.showupAutoFailed,
                                    style: const TextStyle(
                                      color: CupertinoColors.systemRed,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                            buildRedemptionButton: (ctx, onRedeem) => CupertinoButton.filled(
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
      ),
    );
  }
}
