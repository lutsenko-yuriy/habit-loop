import 'package:flutter/foundation.dart' show AsyncCallback, kDebugMode, kProfileMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/notifications/data/test_notification_helper.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/android/language_picker_dialog_android.dart';
import 'package:habit_loop/slices/dashboard/ui/android/onboarding_carousel_android.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_state.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/language_picker_handler.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_status_handler.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_status_view_model.dart';
import 'package:habit_loop/slices/debug/ui/android/remote_config_overrides_page_android.dart';
import 'package:habit_loop/slices/pact/ui/generic/pacts_summary_bar.dart' show PactsPanel;
import 'package:habit_loop/slices/showup/ui/generic/showup_formatters.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_status_colors.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_status_dots.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_ui_state.dart';

class DashboardPageAndroid extends ConsumerWidget {
  final DashboardState state;
  final bool hasPacts;
  final bool showCarousel;
  final ValueChanged<int> onDaySelected;
  final AsyncCallback onCreatePact;
  final Future<void> Function(String) onShowupTapped;

  const DashboardPageAndroid({
    super.key,
    required this.state,
    required this.hasPacts,
    required this.showCarousel,
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
              showMaterialLanguagePicker(context, options, currentOverride, l10n),
        );

    Future<void> onSyncStatusTapped() => openSyncStatusDialog(
          context: context,
          ref: ref,
          showFn: ({required context, required title, required message, required actions}) =>
              _showMaterialSyncDialog(context, title, message, actions),
          messenger: ScaffoldMessenger.of(context),
        );

    // Show the onboarding carousel full-screen (no app bar) when requested.
    // showCarousel is true when there are no pacts + user is anonymous, OR
    // when sign-in is in progress (to avoid a flash of empty dashboard).
    if (showCarousel) {
      return OnboardingCarouselAndroid(onCreatePact: onCreatePact);
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.dashboardTitle),
            if (version.isNotEmpty)
              Text(
                version,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          // ── DEV-ONLY: Remote Config overrides debug screen ─────────────
          if (kDebugMode || kProfileMode)
            IconButton(
              key: const Key('remote-config-debug-button'),
              icon: const Icon(Icons.tune),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RemoteConfigOverridesPageAndroid(),
                ),
              ),
            ),
          // ── DEV-ONLY: fire a test notification in 15 s ─────────────────
          if (kDebugMode || kProfileMode)
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => scheduleTestNotification(ref.read(notificationServiceProvider)),
            ),
          // ── Sync status indicator ──────────────────────────────────────
          IconButton(
            key: const Key('sync-status-button'),
            icon: Icon(
              syncStatusIconData(syncState),
              color: syncStatusIconColor(syncState, context),
            ),
            onPressed: onSyncStatusTapped,
          ),
          // ────────────────────────────────────────────────────────────────
          IconButton(
            key: const Key('language-picker-button'),
            icon: const Icon(Icons.language),
            onPressed: onLanguagePickerTapped,
          ),
        ],
      ),
      floatingActionButton: hasPacts
          ? FloatingActionButton(
              key: const Key('create-pact-button'),
              onPressed: onCreatePact,
              child: const Icon(Icons.add),
            )
          : null,
      body: Stack(
        children: [
          state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _DashboardContent(
                  state: state,
                  l10n: l10n,
                  onDaySelected: onDaySelected,
                  onShowupTapped: onShowupTapped,
                ),
          PactsPanel(onCreatePact: onCreatePact),
        ],
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
        const Divider(height: 1),
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

          return _CalendarDay(
            entry: entry,
            isToday: isToday,
            isSelected: isSelected,
            onTap: () => onDaySelected(index),
            reminderOffsetByPactId: state.reminderOffsetByPactId,
          );
        }),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  final CalendarDayEntry entry;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;
  final Map<String, Duration?> reminderOffsetByPactId;

  const _CalendarDay({
    required this.entry,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
    required this.reminderOffsetByPactId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? theme.colorScheme.primary : null,
              border: isToday && !isSelected ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '${entry.date.day}',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? theme.colorScheme.onPrimary : null,
              ),
            ),
          ),
          const SizedBox(height: 4),
          ShowupStatusDots(
            showups: entry.showups,
            date: entry.date,
            colors: ShowupStatusColors.material(theme.colorScheme),
            uiStates: deriveUiStates(entry.showups, reminderOffsetByPactId),
          ),
        ],
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
    final icon = switch (showup.status) {
      ShowupStatus.done => Icons.check_circle,
      ShowupStatus.failed => Icons.cancel,
      ShowupStatus.pending => Icons.radio_button_unchecked,
    };
    final colors = ShowupStatusColors.material(Theme.of(context).colorScheme);
    final statusText = showupStatusText(l10n, showup.status);

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: colors.forStatus(showup.status)),
      title: Text(habitName),
      subtitle: Text('${l10n.showupDurationMinutes(showup.duration.inMinutes)} — $statusText'),
    );
  }
}

// ---------------------------------------------------------------------------
// Platform-specific sync status dialog — Android (AlertDialog)
// ---------------------------------------------------------------------------

Future<void> _showMaterialSyncDialog(
  BuildContext context,
  String title,
  String message,
  List<SyncDialogAction> actions,
) async {
  // ignore: use_build_context_synchronously — caller guards context.mounted before this call
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: actions.map((a) {
        return TextButton(
          style: a.isDestructive ? TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error) : null,
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
