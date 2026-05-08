import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_ui_state.dart';

/// Helper to build a minimal [Showup] for tests.
Showup _showup({
  ShowupStatus status = ShowupStatus.pending,
  required DateTime scheduledAt,
  Duration duration = const Duration(minutes: 30),
}) {
  return Showup(
    id: 'test-id',
    pactId: 'test-pact',
    scheduledAt: scheduledAt,
    duration: duration,
    status: status,
  );
}

void main() {
  // Anchor all tests to a fixed "now" for determinism.
  final baseTime = DateTime(2026, 5, 8, 10, 0); // 10:00 AM

  group('deriveShowupUiState', () {
    group('done/failed override (rules 1 & 2 — highest priority)', () {
      test('returns done when status is done, even if now is before scheduled', () {
        final showup = _showup(
          status: ShowupStatus.done,
          scheduledAt: baseTime.add(const Duration(hours: 2)), // future
        );
        expect(
          deriveShowupUiState(showup: showup, now: baseTime),
          ShowupUiState.done,
        );
      });

      test('returns failed when status is failed, even if now is before scheduled', () {
        final showup = _showup(
          status: ShowupStatus.failed,
          scheduledAt: baseTime.add(const Duration(hours: 2)), // future
        );
        expect(
          deriveShowupUiState(showup: showup, now: baseTime),
          ShowupUiState.failed,
        );
      });

      test('returns done when status is done and now is inside active window', () {
        final showup = _showup(
          status: ShowupStatus.done,
          scheduledAt: baseTime.subtract(const Duration(minutes: 10)),
        );
        expect(
          deriveShowupUiState(showup: showup, now: baseTime),
          ShowupUiState.done,
        );
      });

      test('returns failed when status is failed and now is after window', () {
        final showup = _showup(
          status: ShowupStatus.failed,
          scheduledAt: baseTime.subtract(const Duration(hours: 2)),
        );
        expect(
          deriveShowupUiState(showup: showup, now: baseTime),
          ShowupUiState.failed,
        );
      });
    });

    group('pending (rule 3 — now >= scheduledAt, status is pending)', () {
      test('returns pending exactly at scheduledAt', () {
        final showup = _showup(scheduledAt: baseTime);
        expect(
          deriveShowupUiState(showup: showup, now: baseTime),
          ShowupUiState.pending,
        );
      });

      test('returns pending when now is inside the active window', () {
        final showup = _showup(scheduledAt: baseTime.subtract(const Duration(minutes: 10)));
        expect(
          deriveShowupUiState(showup: showup, now: baseTime),
          ShowupUiState.pending,
        );
      });

      test('returns pending when now is past the end of the active window (not yet auto-failed)', () {
        final showup = _showup(
          scheduledAt: baseTime.subtract(const Duration(hours: 1)),
          duration: const Duration(minutes: 30),
        );
        expect(
          deriveShowupUiState(showup: showup, now: baseTime),
          ShowupUiState.pending,
        );
      });
    });

    group('waitingForStart (rule 4 — now >= reminderFiresAt, now < scheduledAt)', () {
      test('returns waitingForStart when now is exactly at reminderFiresAt', () {
        final scheduledAt = baseTime.add(const Duration(minutes: 30));
        const reminderOffset = Duration(minutes: 30);
        final showup = _showup(scheduledAt: scheduledAt);
        // reminderFiresAt = scheduledAt - reminderOffset = baseTime
        expect(
          deriveShowupUiState(showup: showup, now: baseTime, reminderOffset: reminderOffset),
          ShowupUiState.waitingForStart,
        );
      });

      test('returns waitingForStart when now is between reminderFiresAt and scheduledAt', () {
        final scheduledAt = baseTime.add(const Duration(minutes: 30));
        const reminderOffset = Duration(hours: 1);
        final reminderFiresAt = scheduledAt.subtract(reminderOffset);
        final now = reminderFiresAt.add(const Duration(minutes: 10));
        final showup = _showup(scheduledAt: scheduledAt);
        expect(
          deriveShowupUiState(showup: showup, now: now, reminderOffset: reminderOffset),
          ShowupUiState.waitingForStart,
        );
      });

      test('returns planned (not waitingForStart) when now is just before reminderFiresAt', () {
        final scheduledAt = baseTime.add(const Duration(hours: 1));
        const reminderOffset = Duration(minutes: 30);
        final reminderFiresAt = scheduledAt.subtract(reminderOffset);
        final now = reminderFiresAt.subtract(const Duration(seconds: 1));
        final showup = _showup(scheduledAt: scheduledAt);
        expect(
          deriveShowupUiState(showup: showup, now: now, reminderOffset: reminderOffset),
          ShowupUiState.planned,
        );
      });
    });

    group('planned (rule 5 — all else)', () {
      test('returns planned when now is well before scheduledAt and no reminderOffset', () {
        final showup = _showup(scheduledAt: baseTime.add(const Duration(hours: 3)));
        expect(
          deriveShowupUiState(showup: showup, now: baseTime),
          ShowupUiState.planned,
        );
      });

      test('returns planned when reminderOffset is null', () {
        final showup = _showup(scheduledAt: baseTime.add(const Duration(hours: 1)));
        expect(
          deriveShowupUiState(showup: showup, now: baseTime, reminderOffset: null),
          ShowupUiState.planned,
        );
      });

      test('returns planned when reminderOffset is zero', () {
        final showup = _showup(scheduledAt: baseTime.add(const Duration(hours: 1)));
        expect(
          deriveShowupUiState(showup: showup, now: baseTime, reminderOffset: Duration.zero),
          ShowupUiState.planned,
        );
      });

      test('returns planned when now is far before the reminder fires', () {
        final scheduledAt = baseTime.add(const Duration(hours: 5));
        const reminderOffset = Duration(minutes: 15);
        final showup = _showup(scheduledAt: scheduledAt);
        // reminderFiresAt = 14:45, now = 10:00 — should be planned
        expect(
          deriveShowupUiState(showup: showup, now: baseTime, reminderOffset: reminderOffset),
          ShowupUiState.planned,
        );
      });
    });

    group('edge cases', () {
      test('done overrides even when now < reminderFiresAt', () {
        final showup = _showup(
          status: ShowupStatus.done,
          scheduledAt: baseTime.add(const Duration(hours: 5)),
        );
        expect(
          deriveShowupUiState(
            showup: showup,
            now: baseTime,
            reminderOffset: const Duration(minutes: 15),
          ),
          ShowupUiState.done,
        );
      });

      test('failed overrides even in the waitingForStart window', () {
        final scheduledAt = baseTime.add(const Duration(minutes: 30));
        const reminderOffset = Duration(hours: 1);
        final showup = _showup(
          status: ShowupStatus.failed,
          scheduledAt: scheduledAt,
        );
        // now is after reminderFiresAt but before scheduledAt
        expect(
          deriveShowupUiState(showup: showup, now: baseTime, reminderOffset: reminderOffset),
          ShowupUiState.failed,
        );
      });
    });
  });
}
