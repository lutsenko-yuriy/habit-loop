import 'package:habit_loop/features/showup/domain/showup.dart';

class DashboardState {
  final List<CalendarDayEntry> calendarDays;
  final int selectedDayIndex;
  final bool isLoading;
  final Map<String, String> pactNames;

  const DashboardState({
    this.calendarDays = const [],
    this.selectedDayIndex = 3,
    this.isLoading = true,
    this.pactNames = const {},
  });

  List<Showup> get selectedDayShowups =>
      calendarDays.isEmpty ? [] : calendarDays[selectedDayIndex].showups;

  String habitName(String pactId) => pactNames[pactId] ?? pactId;

  DashboardState copyWith({
    List<CalendarDayEntry>? calendarDays,
    int? selectedDayIndex,
    bool? isLoading,
    Map<String, String>? pactNames,
  }) {
    return DashboardState(
      calendarDays: calendarDays ?? this.calendarDays,
      selectedDayIndex: selectedDayIndex ?? this.selectedDayIndex,
      isLoading: isLoading ?? this.isLoading,
      pactNames: pactNames ?? this.pactNames,
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
