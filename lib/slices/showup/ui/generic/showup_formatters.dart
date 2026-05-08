import 'package:flutter/widgets.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_ui_state.dart';
import 'package:intl/intl.dart';

/// Formats the scheduled date portion of a showup using the ambient locale
/// (e.g. `3/30/2026` in en, `30/03/2026` in fr). Extracted from the iOS and
/// Android `_ShowupDetailContent` bodies where the same call was duplicated.
String formatShowupDate(BuildContext context, DateTime dateTime) => formatLocaleDate(context, dateTime);

/// Formats the scheduled time portion of a showup using the ambient locale
/// (e.g. `7:30 AM`). Extracted from the iOS and Android `_ShowupDetailContent`
/// bodies where the same call was duplicated.
String formatShowupTime(BuildContext context, DateTime dateTime) =>
    DateFormat.jm(Localizations.localeOf(context).toString()).format(dateTime);

/// Maps a [ShowupStatus] to its localized label shown on the showup detail
/// screen status badge / chip.
String showupStatusText(AppLocalizations l10n, ShowupStatus status) => switch (status) {
      ShowupStatus.pending => l10n.showupPending,
      ShowupStatus.done => l10n.showupDone,
      ShowupStatus.failed => l10n.showupFailed,
    };

/// Maps a [ShowupUiState] to its localized label shown on the showup detail
/// screen status badge / chip and dashboard dot tooltips.
///
/// Use this instead of [showupStatusText] whenever the time-derived UI state
/// is available so that users see "Planned" and "Waiting for start" rather
/// than the raw domain "Pending" label.
String showupUiStateText(AppLocalizations l10n, ShowupUiState state) => switch (state) {
      ShowupUiState.planned => l10n.showupPlanned,
      ShowupUiState.waitingForStart => l10n.showupWaitingForStart,
      ShowupUiState.pending => l10n.showupPending,
      ShowupUiState.done => l10n.showupDone,
      ShowupUiState.failed => l10n.showupFailed,
    };
