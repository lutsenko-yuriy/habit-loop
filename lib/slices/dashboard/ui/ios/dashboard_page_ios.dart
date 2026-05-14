import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show AsyncCallback, kDebugMode, kProfileMode;
import 'package:flutter/material.dart' show Icon, Material, MaterialType, Theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/notifications/data/test_notification_helper.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_state.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/language_picker_handler.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_status_handler.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_status_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pacts_summary_bar.dart' show PactsPanel;
import 'package:habit_loop/slices/showup/ui/generic/showup_formatters.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_status_colors.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_status_dots.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_ui_state.dart';

class DashboardPageIos extends ConsumerWidget {
  final DashboardState state;
  final bool hasPacts;
  final ValueChanged<int> onDaySelected;
  final AsyncCallback onCreatePact;
  final Future<void> Function(String) onShowupTapped;

  const DashboardPageIos({
    super.key,
    required this.state,
    required this.hasPacts,
    required this.onDaySelected,
    required this.onCreatePact,
    required this.onShowupTapped,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final version = ref.watch(appVersionProvider).valueOrNull ?? '';
    final syncState = ref.watch(syncStatusViewModelProvider);

    Future<void> onLanguagePickerTapped() => openLanguagePicker(
          context: context,
          ref: ref,
          showPicker: ({required context, required options, required currentOverride}) =>
              _showCupertinoActionSheet(context, options, currentOverride, l10n),
        );

    Future<void> onSyncStatusTapped() => openSyncStatusDialog(
          context: context,
          ref: ref,
          showFn: ({required context, required title, required message, required actions}) =>
              _showCupertinoSyncDialog(context, title, message, actions),
        );

    return CupertinoPageScaffold(
      backgroundColor:
          hasPacts ? Theme.of(context).colorScheme.surface : CupertinoColors.systemBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          key: const Key('language-picker-button'),
          padding: EdgeInsets.zero,
          onPressed: onLanguagePickerTapped,
          child: const Icon(CupertinoIcons.globe),
        ),
        middle: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.dashboardTitle),
            if (version.isNotEmpty)
              Text(
                version,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── DEV-ONLY: fire a test notification in 15 s ─────────────────
            if (kDebugMode || kProfileMode)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => scheduleTestNotification(ref.read(notificationServiceProvider)),
                child: const Icon(CupertinoIcons.bell),
              ),
            // ── Sync status indicator ───────────────────────────────────────
            CupertinoButton(
              key: const Key('sync-status-button'),
              padding: EdgeInsets.zero,
              onPressed: onSyncStatusTapped,
              child: Icon(
                syncStatusIconData(syncState),
                color: syncStatusIconColor(syncState, context),
              ),
            ),
            // ─────────────────────────────────────────────────────────────
            if (hasPacts)
              CupertinoButton(
                key: const Key('create-pact-button'),
                padding: EdgeInsets.zero,
                onPressed: onCreatePact,
                child: const Icon(CupertinoIcons.add),
              ),
          ],
        ),
      ),
      child: SafeArea(
        key: const Key('dashboard-ios-safe-area'),
        bottom: false,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              state.isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : !hasPacts
                      ? _EmptyState(l10n: l10n, onCreatePact: onCreatePact)
                      : _DashboardContent(
                          state: state,
                          l10n: l10n,
                          onDaySelected: onDaySelected,
                          onShowupTapped: onShowupTapped,
                        ),
              PactsPanel(onCreatePact: onCreatePact),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  final AsyncCallback onCreatePact;

  const _EmptyState({required this.l10n, required this.onCreatePact});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.noPactsYet,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noPactsDescription,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: onCreatePact,
              child: Text(l10n.createPact),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final DashboardState state;
  final AppLocalizations l10n;
  final ValueChanged<int> onDaySelected;
  final Future<void> Function(String) onShowupTapped;

  const _DashboardContent({
    required this.state,
    required this.l10n,
    required this.onDaySelected,
    required this.onShowupTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CalendarStrip(
          state: state,
          onDaySelected: onDaySelected,
        ),
        const _Separator(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: state.selectedDayShowups.isEmpty
                ? Center(
                    key: ValueKey('empty-${state.selectedDayIndex}'),
                    child: Text(l10n.noShowupsForDay),
                  )
                : _ShowupList(
                    key: ValueKey('list-${state.selectedDayIndex}'),
                    showups: state.selectedDayShowups,
                    state: state,
                    onShowupTapped: onShowupTapped,
                  ),
          ),
        ),
      ],
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      color: CupertinoColors.separator,
    );
  }
}

class _CalendarStrip extends StatelessWidget {
  final DashboardState state;
  final ValueChanged<int> onDaySelected;

  const _CalendarStrip({
    required this.state,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final today = state.calendarDays.isNotEmpty ? state.calendarDays[state.todayIndex].date : DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(state.calendarDays.length, (index) {
          final entry = state.calendarDays[index];
          final isToday =
              entry.date.day == today.day && entry.date.month == today.month && entry.date.year == today.year;
          final isSelected = index == state.selectedDayIndex;

          return GestureDetector(
            onTap: () => onDaySelected(index),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? CupertinoTheme.of(context).primaryColor : null,
                    border: isToday && !isSelected
                        ? Border.all(
                            color: CupertinoTheme.of(context).primaryColor,
                            width: 2,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${entry.date.day}',
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? CupertinoColors.white : null,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                ShowupStatusDots(
                  showups: entry.showups,
                  date: entry.date,
                  colors: ShowupStatusColors.cupertino(context),
                  uiStates: deriveUiStates(entry.showups, state.reminderOffsetByPactId),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _ShowupList extends StatelessWidget {
  final List<Showup> showups;
  final DashboardState state;
  final Future<void> Function(String) onShowupTapped;

  const _ShowupList({
    super.key,
    required this.showups,
    required this.state,
    required this.onShowupTapped,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: showups.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final showup = showups[index];
        return _ShowupTile(
          showup: showup,
          habitName: state.habitName(showup.pactId),
          onTap: () => onShowupTapped(showup.id),
        );
      },
    );
  }
}

class _ShowupTile extends StatelessWidget {
  final Showup showup;
  final String habitName;
  final VoidCallback onTap;

  const _ShowupTile({
    required this.showup,
    required this.habitName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusText = showupStatusText(l10n, showup.status);

    return CupertinoListTile(
      backgroundColor: CupertinoColors.transparent,
      onTap: onTap,
      leading: Icon(
        switch (showup.status) {
          ShowupStatus.done => CupertinoIcons.check_mark_circled_solid,
          ShowupStatus.failed => CupertinoIcons.xmark_circle_fill,
          ShowupStatus.pending => CupertinoIcons.circle,
        },
        color: ShowupStatusColors.cupertino(context).forStatus(showup.status),
      ),
      title: Text(habitName),
      subtitle: Text('${l10n.showupDurationMinutes(showup.duration.inMinutes)} — $statusText'),
    );
  }
}

// ---------------------------------------------------------------------------
// Platform-specific picker UI — iOS (CupertinoActionSheet)
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Platform-specific sync status dialog — iOS (CupertinoAlertDialog)
// ---------------------------------------------------------------------------

Future<void> _showCupertinoSyncDialog(
  BuildContext context,
  String title,
  String message,
  List<SyncDialogAction> actions,
) async {
  await showCupertinoDialog<void>(
    context: context,
    // ignore: use_build_context_synchronously — caller guards context.mounted before this call
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: actions.map((a) {
        return CupertinoDialogAction(
          isDestructiveAction: a.isDestructive,
          onPressed: () {
            Navigator.pop(ctx);
            a.onPressed();
          },
          child: Text(a.label),
        );
      }).toList(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Platform-specific picker UI — iOS (CupertinoActionSheet)
// ---------------------------------------------------------------------------

/// Shows a [CupertinoActionSheet] with the given language [options] and returns
/// the selected [Locale], or `null` for the system option or when dismissed.
Future<Locale?> _showCupertinoActionSheet(
  BuildContext context,
  List<({String label, Locale? locale})> options,
  Locale? currentOverride,
  AppLocalizations l10n,
) async {
  String prefixed(String label, Locale? locale) {
    final isSelected = locale == null ? currentOverride == null : currentOverride?.languageCode == locale.languageCode;
    return isSelected ? '✓ $label' : label;
  }

  // Returns (isSystem, locale): isSystem=true means the system option was chosen.
  final result = await showCupertinoModalPopup<(bool isSystem, Locale? locale)>(
    context: context,
    // ignore: use_build_context_synchronously — caller guards context.mounted before this call
    builder: (ctx) => CupertinoActionSheet(
      title: Text(l10n.languagePickerTitle),
      actions: options.map((opt) {
        return CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, (opt.locale == null, opt.locale)),
          child: Text(prefixed(opt.label, opt.locale)),
        );
      }).toList(),
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: Text(l10n.cancel),
      ),
    ),
  );

  if (result == null) return null; // dismissed
  final (isSystem, selectedLocale) = result;
  return isSystem ? null : selectedLocale;
}
