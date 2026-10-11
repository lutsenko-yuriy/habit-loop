import 'package:habit_loop/domain/checklist/pact_checklist_link.dart';

/// Maps [PactChecklistLink] to and from SQLite rows. Local-only: no sync columns.
abstract final class PactChecklistLinkMapper {
  static Map<String, dynamic> toRow(PactChecklistLink link) => {
        'pact_id': link.pactId,
        'checklist_id': link.checklistId,
        'checklist_name': link.checklistName,
        'linked_at': link.linkedAt.millisecondsSinceEpoch,
      };

  /// Dates are restored as local-time [DateTime]s, matching the other mappers.
  static PactChecklistLink fromRow(Map<String, dynamic> row) => PactChecklistLink(
        pactId: row['pact_id'] as String,
        checklistId: row['checklist_id'] as String,
        checklistName: row['checklist_name'] as String,
        linkedAt: DateTime.fromMillisecondsSinceEpoch((row['linked_at'] as num).toInt()),
      );
}
