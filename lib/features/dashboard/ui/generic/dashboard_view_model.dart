import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/features/dashboard/domain/dashboard_state.dart';
import 'package:habit_loop/features/pact/data/pact_repository.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/showup/data/showup_repository.dart';
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
    final pactRepo = ref.read(pactRepositoryProvider);
    final showupRepo = ref.read(showupRepositoryProvider);

    final startDate = DateTime(today.year, today.month, today.day - 3);
    final endDate = DateTime(today.year, today.month, today.day + 3);

    final showups = await showupRepo.getShowupsForDateRange(startDate, endDate);
    final pacts = await pactRepo.getAllPacts();
    final pactNames = {for (final p in pacts) p.id: p.habitName};
    final activePactIds = {
      for (final p in pacts)
        if (p.status == PactStatus.active) p.id
    };

    final days = List.generate(7, (i) {
      final date = DateTime(today.year, today.month, today.day - 3 + i);
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
    );
  }

  void selectDay(int index) {
    state = state.copyWith(selectedDayIndex: index);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
