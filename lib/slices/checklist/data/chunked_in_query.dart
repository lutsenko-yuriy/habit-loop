import 'package:sqflite/sqflite.dart';

/// Queries [table] for rows whose [column] is in [ids], in chunks of 500 to
/// stay under SQLite's bound-variable limit.
Future<List<Map<String, Object?>>> queryByIdsChunked(
  DatabaseExecutor db,
  String table,
  String column,
  List<String> ids,
) async {
  final rows = <Map<String, Object?>>[];
  for (var i = 0; i < ids.length; i += 500) {
    final chunk = ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500);
    rows.addAll(
      await db.query(table, where: '$column IN (${List.filled(chunk.length, '?').join(',')})', whereArgs: chunk),
    );
  }
  return rows;
}
