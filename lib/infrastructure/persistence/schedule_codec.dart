import 'dart:convert';

import 'package:habit_loop/domain/pact/showup_schedule.dart';

/// Encodes and decodes [ShowupSchedule] instances to and from a JSON string
/// suitable for storage in the `schedule` TEXT column of the `pacts` table.
///
/// Discriminated-union format — every JSON object carries a `type` field:
///
/// ```json
/// { "type": "daily",             "timeOfDay": 25200000000 }
/// { "type": "weekday",           "entries": [{ "weekday": 1, "timeOfDay": 25200000000 }] }
/// { "type": "monthlyByWeekday",  "entries": [{ "occurrence": 1, "weekday": 1, "timeOfDay": 25200000000 }] }
/// { "type": "monthlyByDate",     "entries": [{ "dayOfMonth": 1, "timeOfDay": 25200000000 }] }
/// ```
///
/// All `timeOfDay` values are stored as `int` microseconds
/// ([Duration.inMicroseconds]) to preserve full [Duration] precision.
abstract final class ScheduleCodec {
  /// Encodes [schedule] to a JSON string.
  static String encode(ShowupSchedule schedule) {
    return jsonEncode(_toJson(schedule));
  }

  /// Decodes [json] back into a [ShowupSchedule].
  ///
  /// Throws [FormatException] if [json] is not valid JSON, or if the JSON root
  /// is not an object (e.g. a string, number, or array). The type guard prevents
  /// a silent [TypeError] from the `as Map<String, dynamic>` cast when the DB
  /// column contains syntactically valid but non-object JSON.
  /// Throws [ArgumentError] if the `type` discriminator is unknown.
  static ShowupSchedule decode(String json) {
    final raw = jsonDecode(json);
    if (raw is! Map<String, dynamic>) {
      throw FormatException('Expected a JSON object, got ${raw.runtimeType}: $json');
    }
    return _fromJson(raw);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _toJson(ShowupSchedule schedule) {
    return switch (schedule) {
      DailySchedule(:final timeOfDay) => {
          'type': 'daily',
          'timeOfDay': timeOfDay.inMicroseconds,
        },
      WeekdaySchedule(:final entries) => {
          'type': 'weekday',
          'entries': entries
              .map(
                (e) => {
                  'weekday': e.weekday,
                  'timeOfDay': e.timeOfDay.inMicroseconds,
                },
              )
              .toList(),
        },
      MonthlyByWeekdaySchedule(:final entries) => {
          'type': 'monthlyByWeekday',
          'entries': entries
              .map(
                (e) => {
                  'occurrence': e.occurrence,
                  'weekday': e.weekday,
                  'timeOfDay': e.timeOfDay.inMicroseconds,
                },
              )
              .toList(),
        },
      MonthlyByDateSchedule(:final entries) => {
          'type': 'monthlyByDate',
          'entries': entries
              .map(
                (e) => {
                  'dayOfMonth': e.dayOfMonth,
                  'timeOfDay': e.timeOfDay.inMicroseconds,
                },
              )
              .toList(),
        },
    };
  }

  static ShowupSchedule _fromJson(Map<String, dynamic> map) {
    final type = map['type'] as String?;
    return switch (type) {
      'daily' => DailySchedule(
          timeOfDay: Duration(microseconds: (map['timeOfDay'] as num).toInt()),
        ),
      'weekday' => WeekdaySchedule(
          entries: (map['entries'] as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .map(
                (e) => WeekdayEntry(
                  weekday: (e['weekday'] as num).toInt(),
                  timeOfDay: Duration(microseconds: (e['timeOfDay'] as num).toInt()),
                ),
              )
              .toList(),
        ),
      'monthlyByWeekday' => MonthlyByWeekdaySchedule(
          entries: (map['entries'] as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .map(
                (e) => MonthlyWeekdayEntry(
                  occurrence: (e['occurrence'] as num).toInt(),
                  weekday: (e['weekday'] as num).toInt(),
                  timeOfDay: Duration(microseconds: (e['timeOfDay'] as num).toInt()),
                ),
              )
              .toList(),
        ),
      'monthlyByDate' => MonthlyByDateSchedule(
          entries: (map['entries'] as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .map(
                (e) => MonthlyDateEntry(
                  dayOfMonth: (e['dayOfMonth'] as num).toInt(),
                  timeOfDay: Duration(microseconds: (e['timeOfDay'] as num).toInt()),
                ),
              )
              .toList(),
        ),
      _ => throw ArgumentError.value(type, 'type', 'Unknown ShowupSchedule type'),
    };
  }
}
