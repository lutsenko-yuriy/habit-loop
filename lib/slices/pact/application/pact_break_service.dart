import 'dart:async';

import 'package:habit_loop/domain/pact/break_derivation.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_break_repository.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/infrastructure/sync/sync_service.dart';
import 'package:habit_loop/slices/pact/application/pact_detail_cache.dart';
import 'package:habit_loop/slices/reminder/application/reminder_scheduling_service.dart';

/// Owns pact-break creation and resolution (HAB-195): starting a break,
/// stopping ("Resume pact") it, and querying the break that currently blocks
/// a pact from starting another one.
class PactBreakService {
  PactBreakService({
    required PactBreakRepository pactBreakRepository,
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
    required ReminderSchedulingService reminderSchedulingService,
    required SyncService syncService,
    required PactDetailCache cache,
  })  : _pactBreakRepository = pactBreakRepository,
        _pactRepository = pactRepository,
        _showupRepository = showupRepository,
        _reminderSchedulingService = reminderSchedulingService,
        _syncService = syncService,
        _cache = cache;

  final PactBreakRepository _pactBreakRepository;
  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;
  final ReminderSchedulingService _reminderSchedulingService;
  final SyncService _syncService;
  final PactDetailCache _cache;

  /// The single break that currently blocks a new one from starting for
  /// [pactId] — i.e. the one unresolved (active-or-scheduled) break, if any.
  /// Only one can exist at a time; [startBreak] enforces this.
  Future<PactBreak?> getActiveBreak(String pactId, {required DateTime now}) async {
    final breaks = await _pactBreakRepository.getBreaksForPact(pactId);
    for (final b in breaks) {
      if (!b.isResolved(now)) return b;
    }
    return null;
  }

  /// All breaks (stopped and unstopped) recorded for [pactId], oldest first.
  Future<List<PactBreak>> getBreaksForPact(String pactId) => _pactBreakRepository.getBreaksForPact(pactId);

  /// This pact's showups' scheduled times, unsorted — a thin pass-through so
  /// break-creation UI (e.g. the "next showup" hint, HAB-215) doesn't have to
  /// reach into the showup slice's repository directly; this service already
  /// holds one for [_cancelInWindowReminders]/[_rescheduleRemindersAfterStop].
  Future<List<DateTime>> getShowupScheduledDatesForPact(String pactId) async {
    final showups = await _showupRepository.getShowupsForPact(pactId);
    return showups.map((s) => s.scheduledAt).toList();
  }

  /// Starts a new break, cancels reminders for showups already inside its
  /// window, and write-through syncs it.
  ///
  /// Throws [ArgumentError] if [rationale] is empty or only whitespace, and
  /// [StateError] if [pactId] already has an unresolved break.
  Future<PactBreak> startBreak({
    required String id,
    required String pactId,
    required DateTime startDate,
    required String rationale,
    required DateTime now,
    DateTime? plannedEndDate,
  }) async {
    if (rationale.trim().isEmpty) {
      throw ArgumentError.value(rationale, 'rationale', 'must not be empty');
    }

    final existing = await getActiveBreak(pactId, now: now);
    if (existing != null) {
      throw StateError('Pact $pactId already has an unresolved break (${existing.id}).');
    }

    final pactBreak = PactBreak(
      id: id,
      pactId: pactId,
      startDate: startDate,
      rationale: rationale,
      plannedEndDate: plannedEndDate,
      createdAt: now,
    );

    await _pactBreakRepository.saveBreak(pactBreak);
    unawaited(_syncService.uploadPactBreak(pactBreak));
    await _cancelInWindowReminders(pactBreak);
    _cache.evict(pactId);

    // HAB-227/HAB-234: reconcile welcome-back reminders across *all* of the
    // pact's breaks now, not just this new one — the new break's window may
    // shadow an earlier break's still-unpersisted welcome-back target (the
    // showup-repository-only sweep above can't reach it), and this new break
    // needs its own welcome-back reminder scheduled too.
    final pact = await _pactRepository.getPactById(pactId);
    if (pact != null) {
      final allBreaks = await _pactBreakRepository.getBreaksForPact(pactId);
      await reconcileWelcomeBackReminders(pact: pact, breaks: allBreaks, now: now);
    }

    return pactBreak;
  }

  /// Stops ("Resume pact") the break identified by [breakId], fixing its
  /// window at [now] (or its planned end, if that already elapsed — see
  /// [PactBreak.stop]). Showups already on-break before this call keep that
  /// marking permanently; only future scheduling resumes.
  ///
  /// Throws [ArgumentError] if no break with [breakId] exists.
  Future<PactBreak> stopBreak(String breakId, {required DateTime now}) async {
    final existing = await _pactBreakRepository.getBreakById(breakId);
    if (existing == null) {
      throw ArgumentError.value(breakId, 'breakId', 'no PactBreak found with this id');
    }

    final stopped = existing.stop(now);
    await _pactBreakRepository.updateBreak(stopped);
    unawaited(_syncService.uploadPactBreak(stopped));
    _cache.evict(stopped.pactId);
    await _rescheduleRemindersAfterStop(original: existing, stopped: stopped, now: now);

    final pact = await _pactRepository.getPactById(stopped.pactId);
    if (pact != null) {
      final allBreaks = await _pactBreakRepository.getBreaksForPact(stopped.pactId);
      await reconcileWelcomeBackReminders(pact: pact, breaks: allBreaks, now: now);
    }

    return stopped;
  }

  /// HAB-227/HAB-234: brings every welcome-back-eligible reminder for [pact]
  /// in line with what [breaks] currently says it should be. Stateless and
  /// idempotent — safe to call after any break mutation (start, stop) and
  /// from a periodic sweep (e.g. dashboard load, to pick up breaks changed by
  /// sync on another device), since nothing about "which showup gets the
  /// welcome-back text" is ever persisted; it's always recomputed here.
  ///
  /// For each break's target showup (may not be persisted yet):
  /// - if another break's window now covers it, its reminder — welcome-back
  ///   or not — must not fire: cancel it outright. This is the fix for the
  ///   reported bug, where a later break's cancel-in-window sweep only
  ///   reached persisted showups and missed an earlier break's synthetic
  ///   target.
  /// - otherwise, reschedule it. `scheduleRemindersForShowups` re-derives the
  ///   correct text from the current [breaks] — welcome-back if the break
  ///   still qualifies, standard text if (e.g.) it was resumed early since
  ///   the reminder was first armed.
  ///
  /// Cancels and schedules are batched (one `scheduleRemindersForShowups`
  /// call for every target that needs it, not one per break) — two breaks
  /// can legitimately share the same target showup, and a per-break call
  /// would double-count it in `NotificationsScheduledEvent` analytics.
  Future<void> reconcileWelcomeBackReminders({
    required Pact pact,
    required List<PactBreak> breaks,
    required DateTime now,
  }) async {
    if (pact.reminderOffset == null || breaks.isEmpty) return;

    final toSchedule = <String, Showup>{};
    for (final b in breaks) {
      // Probe with stoppedAt cleared: the target showup id is a function of
      // plannedEndDate alone (see BreakDerivation.firstShowupAfterBreak) —
      // whether *this* break still qualifies for welcome-back text (as
      // opposed to standard text, e.g. because it was resumed early) is
      // decided below by scheduleRemindersForShowups itself, via the real,
      // unprobed `b` inside `breaks`.
      final target = BreakDerivation.firstShowupAfterBreak(pact, b.copyWith(clearStoppedAt: true));
      if (target == null) continue;

      final otherBreaks = breaks.where((other) => other.id != b.id).toList();
      if (BreakDerivation.isShowupOnBreak(showup: target, breaks: otherBreaks)) {
        await _reminderSchedulingService.cancelRemindersForShowup(target.id);
      } else {
        toSchedule[target.id] = target;
      }
    }

    if (toSchedule.isEmpty) return;
    await _reminderSchedulingService.scheduleRemindersForShowups(
      pact: pact,
      showups: toSchedule.values.toList(),
      now: now,
      breaks: breaks,
    );
  }

  Future<void> _cancelInWindowReminders(PactBreak pactBreak) async {
    final showups = await _showupRepository.getShowupsForPact(pactBreak.pactId);
    for (final showup in showups) {
      if (BreakDerivation.isShowupOnBreak(showup: showup, breaks: [pactBreak])) {
        await _reminderSchedulingService.cancelRemindersForShowup(showup.id);
      }
    }
  }

  // Reminders cancelled by _cancelInWindowReminders when the break started are
  // not restored by anything else once it ends — auto-fail resumes "for free"
  // because on-break state is derived at read time, but notification
  // scheduling is a one-shot side effect (HAB-195 WU3). Only showups that were
  // inside the break's *original* (pre-stop) window and are no longer covered
  // by any of the pact's remaining breaks are rescheduled — showups still
  // inside the now-clamped window stay on-break permanently, per spec.
  Future<void> _rescheduleRemindersAfterStop({
    required PactBreak original,
    required PactBreak stopped,
    required DateTime now,
  }) async {
    final pact = await _pactRepository.getPactById(stopped.pactId);
    if (pact == null || pact.reminderOffset == null) return;

    final remainingBreaks = await _pactBreakRepository.getBreaksForPact(stopped.pactId);
    final showups = await _showupRepository.getShowupsForPact(stopped.pactId);

    final toReschedule = showups
        .where((s) =>
            BreakDerivation.isShowupOnBreak(showup: s, breaks: [original]) &&
            !BreakDerivation.isShowupOnBreak(showup: s, breaks: remainingBreaks))
        .toList();

    if (toReschedule.isEmpty) return;
    await _reminderSchedulingService.scheduleRemindersForShowups(
      pact: pact,
      showups: toReschedule,
      now: now,
      breaks: remainingBreaks,
    );
  }
}
