import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/features/dashboard/domain/dashboard_state.dart';
import 'package:habit_loop/features/pact/data/pact_repository.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/showup/data/showup_repository.dart';
import 'package:habit_loop/features/showup/domain/showup_generation_service.dart';

final todayProvider = Provider<DateTime>((ref) => DateTime.now());

final pactRepositoryProvider = Provider<PactRepository>((ref) {
  throw UnimplementedError('Override pactRepositoryProvider');
});

final showupRepositoryProvider = Provider<ShowupRepository>((ref) {
  throw UnimplementedError('Override showupRepositoryProvider');
});

final dashboardViewModelProvider =
    NotifierProvider<DashboardViewModel, DashboardState>(
  DashboardViewModel.new,
);

final hasActivePactsProvider = FutureProvider<bool>((ref) async {
  final pactRepo = ref.watch(pactRepositoryProvider);
  final pacts = await pactRepo.getActivePacts();
  return pacts.isNotEmpty;
});

class DashboardViewModel extends Notifier<DashboardState> {
  @override
  DashboardState build() {
    return const DashboardState();
  }

  Future<void> load() async {
    final today = ref.read(todayProvider);
    final todayNorm = DateTime(today.year, today.month, today.day);
    final pactRepo = ref.read(pactRepositoryProvider);
    final showupRepo = ref.read(showupRepositoryProvider);

    final allPacts = await pactRepo.getAllPacts();
    final activePacts = allPacts.where((p) => p.status == PactStatus.active).toList();
    final pactNames = {for (final p in allPacts) p.id: p.habitName};
    final activePactIds = {for (final p in activePacts) p.id};

    // -----------------------------------------------------------------------
    // Lazy generation: ensure showups exist for each active pact in the
    // window [today, today + 10] before reading from the repository.
    // The window is intentionally wider than the 7-day calendar strip so that
    // a DST-caused 1-day shortfall still covers all visible strip days.
    // -----------------------------------------------------------------------
    final generationWindowEnd = todayNorm.add(const Duration(days: 10));
    final generationService = ShowupGenerationService(repository: showupRepo);
    for (final pact in activePacts) {
      await generationService.ensureShowupsExist(
        pact,
        from: todayNorm,
        to: generationWindowEnd,
      );
    }

    // -----------------------------------------------------------------------
    // todayIndex: gradual ramp over the first 3 days after the user created
    // their very first pact, then stays centred (3) thereafter.
    //
    // Formula: min(daysSinceOldestPact, 3) where
    //   daysSinceOldestPact = today.difference(oldestStartDate).inDays
    //
    // ALL pacts (active, stopped, completed) contribute to finding the oldest
    // start date so that deleting or stopping a pact never shifts the strip.
    //
    //   Day 1 (today == oldestStartDate)        → todayIndex = 0
    //   Day 2 (today == oldestStartDate + 1)    → todayIndex = 1
    //   Day 3 (today == oldestStartDate + 2)    → todayIndex = 2
    //   Day 4+ (today >= oldestStartDate + 3)   → todayIndex = 3
    // -----------------------------------------------------------------------
    int computedTodayIndex = 3;
    if (allPacts.isNotEmpty) {
      DateTime? earliestStart;
      for (final p in allPacts) {
        final start = DateTime(p.startDate.year, p.startDate.month, p.startDate.day);
        if (earliestStart == null || start.isBefore(earliestStart)) {
          earliestStart = start;
        }
      }
      if (earliestStart != null) {
        final daysSince = todayNorm.difference(earliestStart).inDays;
        computedTodayIndex = daysSince.clamp(0, 3);
      }
    }

    // -----------------------------------------------------------------------
    // Build the 7-day strip starting from today - computedTodayIndex.
    // -----------------------------------------------------------------------
    final stripStart = DateTime(todayNorm.year, todayNorm.month, todayNorm.day - computedTodayIndex);
    final stripEnd = DateTime(todayNorm.year, todayNorm.month, todayNorm.day + (6 - computedTodayIndex));

    final showups = await showupRepo.getShowupsForDateRange(stripStart, stripEnd);

    final days = List.generate(7, (i) {
      final date = DateTime(stripStart.year, stripStart.month, stripStart.day + i);
      final dayShowups = showups
          .where((s) =>
              _sameDay(s.scheduledAt, date) && activePactIds.contains(s.pactId))
          .toList();
      return CalendarDayEntry(date: date, showups: dayShowups);
    });

    state = state.copyWith(
      calendarDays: days,
      pactNames: pactNames,
      isLoading: false,
      todayIndex: computedTodayIndex,
      selectedDayIndex: computedTodayIndex,
    );
  }

  void selectDay(int index) {
    state = state.copyWith(selectedDayIndex: index);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
