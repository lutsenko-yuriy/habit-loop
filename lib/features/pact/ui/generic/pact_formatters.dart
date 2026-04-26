import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

/// Maps a [PactStatus] to its localized label shown on pact detail, pact list
/// tiles, and summary bars. Extracted to one place so the three call sites
/// cannot drift apart.
String pactStatusText(AppLocalizations l10n, PactStatus status) => switch (status) {
      PactStatus.active => l10n.pactStatusActive,
      PactStatus.stopped => l10n.pactStatusStopped,
      PactStatus.completed => l10n.pactStatusCompleted,
    };
