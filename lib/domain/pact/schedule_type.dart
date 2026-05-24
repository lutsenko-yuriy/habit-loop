/// The schedule varieties a pact can use.
///
/// [slot] is the new card-based schedule introduced in HAB-80.  The legacy
/// types ([daily], [weekday], [monthlyByWeekday], [monthlyByDate]) remain for
/// backward compatibility — existing pacts stored with those types continue to
/// load and display correctly.
enum ScheduleType { daily, weekday, monthlyByWeekday, monthlyByDate, slot }
