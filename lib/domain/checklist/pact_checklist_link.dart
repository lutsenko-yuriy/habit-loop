/// The Checklister checklist a pact is linked to. One per pact; [pactId] is the key.
///
/// Local-only (not synced): Checklister's checklist ids are local to the device.
class PactChecklistLink {
  final String pactId;
  final String checklistId;
  final String checklistName;
  final DateTime linkedAt;

  const PactChecklistLink({
    required this.pactId,
    required this.checklistId,
    required this.checklistName,
    required this.linkedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PactChecklistLink &&
          pactId == other.pactId &&
          checklistId == other.checklistId &&
          checklistName == other.checklistName &&
          linkedAt == other.linkedAt;

  @override
  int get hashCode => Object.hash(pactId, checklistId, checklistName, linkedAt);
}
