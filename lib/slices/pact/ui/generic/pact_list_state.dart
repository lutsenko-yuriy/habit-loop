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
  /// just like the status chips. It splits the Active bucket into two
  /// mutually exclusive parts: an on-break pact is matched *only* by this
  /// flag, never by [activeFilters] containing [PactStatus.active] — so
  /// Active selected + Break deselected shows active-but-not-on-break pacts
  /// only, and Break selected + Active deselected shows on-break pacts only.
  /// A non-active pact is entirely unaffected by this flag.
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
    this.breakSelected = true,
  });

  int get activeCount => entries.where((e) => e.pact.status == PactStatus.active).length;

  int get doneCount => entries.where((e) => e.pact.status == PactStatus.completed).length;

  int get cancelledCount => entries.where((e) => e.pact.status == PactStatus.stopped).length;

  int get archivedCount => entries.where((e) => e.pact.archived).length;

  int get archivedDoneCount => entries.where((e) => e.pact.archived && e.pact.status == PactStatus.completed).length;

  int get archivedCancelledCount => entries.where((e) => e.pact.archived && e.pact.status == PactStatus.stopped).length;

  List<PactListEntry> get filteredEntries => entries
      .where((e) => e.onBreak ? breakSelected : activeFilters.contains(e.pact.status))
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
