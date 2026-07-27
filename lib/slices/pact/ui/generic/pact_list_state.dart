import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';

class PactListEntry {
  final Pact pact;

  /// The next scheduled pending showup time, only set for active pacts.
  final DateTime? nextShowupAt;

  /// True iff this pact is active and currently has an unresolved break
  /// (HAB-195). Always false for non-active pacts.
  final bool onBreak;

  const PactListEntry({required this.pact, this.nextShowupAt, this.onBreak = false});
}

class PactListState {
  final List<PactListEntry> entries;
  final bool isLoading;
  final Set<PactStatus> activeFilters;
  final bool showArchived;

  /// "Break" chip (HAB-195) — kept separate from [activeFilters] since Break
  /// isn't a [PactStatus], but otherwise an independent multi-select toggle
  /// just like the status chips: selecting it adds on-break entries to
  /// whatever [activeFilters] already shows (OR, not a replacement), exactly
  /// mirroring how selecting an additional status chip adds its entries.
  final bool breakSelected;

  const PactListState({
    this.entries = const [],
    this.isLoading = false,
    this.activeFilters = const {
      PactStatus.active,
      PactStatus.completed,
      PactStatus.stopped,
    },
    this.showArchived = false,
    this.breakSelected = false,
  });

  int get activeCount => entries.where((e) => e.pact.status == PactStatus.active).length;

  int get doneCount => entries.where((e) => e.pact.status == PactStatus.completed).length;

  int get cancelledCount => entries.where((e) => e.pact.status == PactStatus.stopped).length;

  int get archivedCount => entries.where((e) => e.pact.archived).length;

  int get archivedDoneCount => entries.where((e) => e.pact.archived && e.pact.status == PactStatus.completed).length;

  int get archivedCancelledCount => entries.where((e) => e.pact.archived && e.pact.status == PactStatus.stopped).length;

  List<PactListEntry> get filteredEntries => entries
      .where((e) => activeFilters.contains(e.pact.status) || (breakSelected && e.onBreak))
      .where((e) => showArchived || !e.pact.archived)
      .toList();

  PactListState copyWith({
    List<PactListEntry>? entries,
    bool? isLoading,
    Set<PactStatus>? activeFilters,
    bool? showArchived,
    bool? breakSelected,
  }) {
    return PactListState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      activeFilters: activeFilters ?? this.activeFilters,
      showArchived: showArchived ?? this.showArchived,
      breakSelected: breakSelected ?? this.breakSelected,
    );
  }
}
