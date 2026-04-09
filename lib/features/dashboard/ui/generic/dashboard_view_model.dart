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
    // window [today, today + 7] before reading from the repository.
    // -----------------------------------------------------------------------
    final generationWindowEnd = DateTime(todayNorm.year, todayNorm.month, todayNorm.day + 7);
    final generationService = ShowupGenerationService(repository: showupRepo);
    for (final pact in activePacts) {
      await generationService.ensureShowupsExist(
        pact,
        from: todayNorm,
        to: generationWindowEnd,
      );
    }

    // -----------------------------------------------------------------------
    // todayIndex: how many days after the earliest active pact start date is
    // today? Clamped to [0, 3]. Defaults to 3 when there are no active pacts.
    // -----------------------------------------------------------------------
    int computedTodayIndex = 3;
    if (activePacts.isNotEmpty) {
      DateTime? earliestStart;
      for (final p in activePacts) {
        final start = DateTime(p.startDate.year, p.startDate.month, p.startDate.day);
        if (earliestStart == null || start.isBefore(earliestStart)) {
          earliestStart = start;
        }
      }
      if (earliestStart != null) {
        final daysSinceStart = todayNorm.difference(earliestStart).inDays;
        computedTodayIndex = daysSinceStart.clamp(0, 3);
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
