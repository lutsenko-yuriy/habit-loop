import 'package:habit_loop/domain/showup/showup.dart';

class DashboardState {
  final List<CalendarDayEntry> calendarDays;
  final int selectedDayIndex;
  final bool isLoading;
  final Map<String, String> pactNames;

  /// The index within [calendarDays] at which "today" sits.
  ///
  /// Normally 3 (centred layout), but shifts to 0, 1, or 2 during the first
  /// three days after the earliest active pact was created so that today is
  /// never preceded by calendar days that pre-date the user's pacts.
  final int todayIndex;

  /// Reminder offsets keyed by pact ID. Used by the dashboard UI to derive
  /// time-based [ShowupUiState] for each showup dot without a second DB
  /// round-trip. A null value means the pact has no reminder set.
  final Map<String, Duration?> reminderOffsetByPactId;

  const DashboardState({
    this.calendarDays = const [],
    this.selectedDayIndex = 3,
    this.isLoading = true,
    this.pactNames = const {},
    this.todayIndex = 3,
    this.reminderOffsetByPactId = const {},
  });

  List<Showup> get selectedDayShowups => calendarDays.isEmpty ? [] : calendarDays[selectedDayIndex].showups;

  String habitName(String pactId) => pactNames[pactId] ?? pactId;

  DashboardState copyWith({
    List<CalendarDayEntry>? calendarDays,
    int? selectedDayIndex,
    bool? isLoading,
    Map<String, String>? pactNames,
    int? todayIndex,
    Map<String, Duration?>? reminderOffsetByPactId,
  }) {
    return DashboardState(
      calendarDays: calendarDays ?? this.calendarDays,
      selectedDayIndex: selectedDayIndex ?? this.selectedDayIndex,
      isLoading: isLoading ?? this.isLoading,
      pactNames: pactNames ?? this.pactNames,
      todayIndex: todayIndex ?? this.todayIndex,
      reminderOffsetByPactId: reminderOffsetByPactId ?? this.reminderOffsetByPactId,
    );
  }
}

class CalendarDayEntry {
  final DateTime date;
  final List<Showup> showups;

  const CalendarDayEntry({
    required this.date,
    this.showups = const [],
  });
}
