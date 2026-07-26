import 'package:flutter/material.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/theme/colors.dart';
import 'package:habit_loop/theme/spacing.dart';
import 'package:habit_loop/theme/typography.dart';
import 'package:habit_loop/theme/widgets/animated_reveal.dart';

/// "In a break" banner + "Resume pact" action for Pact Detail (HAB-195
/// WU5.2), shared by both `pact_detail_page_ios.dart` and `_android.dart` —
/// unlike the rest of those two screens (which render platform-authentic
/// Cupertino/Material widgets throughout), this banner uses plain Material
/// widgets on both platforms. That's safe because the iOS page already
/// wraps its body in a `Material(type: MaterialType.transparency)` ancestor
/// specifically to host embedded Material content, and it keeps the banner
/// itself — a simple colored info box, not a platform-idiomatic control —
/// identical pixel-for-pixel on both platforms rather than duplicated.
class BreakBanner extends StatelessWidget {
  final PactBreak activeBreak;
  final bool isStopping;
  final Object? stopError;
  final Future<void> Function()? onStopBreak;
  final AppLocalizations l10n;

  const BreakBanner({
    super.key,
    required this.activeBreak,
    required this.isStopping,
    required this.stopError,
    required this.onStopBreak,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const color = HabitLoopColors.onBreak;
    final plannedEnd = activeBreak.plannedEndDate;

    return Container(
      key: const Key('pact-detail-break-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pause_circle_filled, size: 18, color: color),
                        const SizedBox(width: AppSpacing.s8),
                        Text(
                          l10n.pactOnBreakTitle,
                          style: AppTypography.body.copyWith(color: color, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(activeBreak.rationale, style: AppTypography.body),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      plannedEnd != null
                          ? '${l10n.pactBreakUntilLabel} ${formatLocaleDate(plannedEnd)}'
                          : l10n.breakUntilPactEnds,
                      style: AppTypography.caption.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              TextButton(
                key: const Key('pact-detail-resume-pact-button'),
                style: TextButton.styleFrom(foregroundColor: color),
                onPressed: isStopping || onStopBreak == null ? null : () => _confirmResume(context),
                child: isStopping
                    ? const SizedBox(
                        height: AppSpacing.s20,
                        width: AppSpacing.s20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: color),
                      )
                    : Text(l10n.resumePact),
              ),
            ],
          ),
          if (stopError != null) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(l10n.resumePactError, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmResume(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.resumePactTitle),
        content: Text(l10n.resumePactBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.resumePactConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await onStopBreak?.call();
    }
  }
}

/// Remembers the last non-null [activeBreak] so [BreakBanner] can keep
/// rendering — and fade/collapse via [AnimatedReveal] — for the instant
/// after [activeBreak] goes null following a successful resume, instead of
/// the banner disappearing on the next frame.
class BreakBannerReveal extends StatefulWidget {
  final PactBreak? activeBreak;
  final bool isStopping;
  final Object? stopError;
  final Future<void> Function()? onStopBreak;
  final AppLocalizations l10n;

  const BreakBannerReveal({
    super.key,
    required this.activeBreak,
    required this.isStopping,
    required this.stopError,
    required this.onStopBreak,
    required this.l10n,
  });

  @override
  State<BreakBannerReveal> createState() => _BreakBannerRevealState();
}

class _BreakBannerRevealState extends State<BreakBannerReveal> {
  PactBreak? _lastBreak;

  @override
  void initState() {
    super.initState();
    _lastBreak = widget.activeBreak;
  }

  @override
  void didUpdateWidget(covariant BreakBannerReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeBreak != null) _lastBreak = widget.activeBreak;
  }

  @override
  Widget build(BuildContext context) {
    final activeBreak = _lastBreak;
    return AnimatedReveal(
      visible: widget.activeBreak != null,
      child: activeBreak == null
          ? const SizedBox.shrink()
          : Column(
              children: [
                BreakBanner(
                  activeBreak: activeBreak,
                  isStopping: widget.isStopping,
                  stopError: widget.stopError,
                  onStopBreak: widget.onStopBreak,
                  l10n: widget.l10n,
                ),
                const SizedBox(height: AppSpacing.s24),
              ],
            ),
    );
  }
}
