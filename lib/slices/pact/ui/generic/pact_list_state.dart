import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';

class PactListEntry {
  final Pact pact;

  /// The next scheduled pending showup time, only set for active pacts.
  final DateTime? nextShowupAt;

  const PactListEntry({required this.pact, this.nextShowupAt});
}

class PactListState {
  final List<PactListEntry> entries;
  final bool isLoading;
  final Set<PactStatus> activeFilters;
  final bool showArchived;

  const PactListState({
    this.entries = const [],
    this.isLoading = false,
    this.activeFilters = const {
      PactStatus.active,
      PactStatus.completed,
      PactStatus.stopped,
    },
    this.showArchived = false,
  });

  int get activeCount => entries.where((e) => e.pact.status == PactStatus.active).length;

  int get doneCount => entries.where((e) => e.pact.status == PactStatus.completed).length;

  int get cancelledCount => entries.where((e) => e.pact.status == PactStatus.stopped).length;

  int get archivedCount => entries.where((e) => e.pact.archived).length;

  int get archivedDoneCount => entries.where((e) => e.pact.archived && e.pact.status == PactStatus.completed).length;

  int get archivedCancelledCount => entries.where((e) => e.pact.archived && e.pact.status == PactStatus.stopped).length;

  List<PactListEntry> get filteredEntries => entries
      .where((e) => activeFilters.contains(e.pact.status))
      .where((e) => showArchived || !e.pact.archived)
      .toList();

  PactListState copyWith({
    List<PactListEntry>? entries,
    bool? isLoading,
    Set<PactStatus>? activeFilters,
    bool? showArchived,
  }) {
    return PactListState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      activeFilters: activeFilters ?? this.activeFilters,
      showArchived: showArchived ?? this.showArchived,
    );
  }
}
