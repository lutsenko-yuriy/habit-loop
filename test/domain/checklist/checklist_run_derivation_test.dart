import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/checklist/checklist_run.dart';
import 'package:habit_loop/domain/checklist/checklist_run_derivation.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';

void main() {
  final scheduled = DateTime(2026, 3, 1, 8);
  const duration = Duration(minutes: 30);
  final windowEnd = scheduled.add(duration);

  Showup showup([ShowupStatus status = ShowupStatus.pending]) =>
      Showup(id: 's', pactId: 'p', scheduledAt: scheduled, duration: duration, status: status);
  ChecklistRun run(DateTime startedAt) =>
      ChecklistRun(showupId: 's', pactId: 'p', checklistId: 'c', startedAt: startedAt);

  bool suppresses({Showup? s, ChecklistRun? r, required DateTime now}) =>
      ChecklistRunDerivation.suppressesAutoFail(showup: s ?? showup(), run: r, now: now);

  test('no run -> false', () => expect(suppresses(now: windowEnd.add(const Duration(minutes: 1))), isFalse));

  test('run started in window, now within grace -> true', () {
    expect(suppresses(r: run(scheduled), now: windowEnd.add(const Duration(minutes: 5))), isTrue);
  });

  test('now exactly at grace boundary -> true; one minute later -> false', () {
    expect(suppresses(r: run(scheduled), now: windowEnd.add(const Duration(minutes: 15))), isTrue);
    expect(suppresses(r: run(scheduled), now: windowEnd.add(const Duration(minutes: 16))), isFalse);
  });

  test('run started exactly at window end -> true; after window end -> false', () {
    expect(suppresses(r: run(windowEnd), now: windowEnd), isTrue);
    expect(suppresses(r: run(windowEnd.add(const Duration(minutes: 1))), now: windowEnd), isFalse);
  });

  test('non-pending showup -> false', () {
    expect(suppresses(s: showup(ShowupStatus.done), r: run(scheduled), now: windowEnd), isFalse);
    expect(suppresses(s: showup(ShowupStatus.failed), r: run(scheduled), now: windowEnd), isFalse);
  });
}
