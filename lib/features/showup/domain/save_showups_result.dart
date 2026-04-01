/// Result of a bulk [saveShowups] operation.
class SaveShowupsResult {
  /// Number of showups that were successfully saved.
  final int savedCount;

  /// IDs of showups that were skipped because they already existed.
  final List<String> skippedIds;

  SaveShowupsResult({
    required this.savedCount,
    required List<String> skippedIds,
  }) : skippedIds = List.unmodifiable(skippedIds);

  /// True if all showups were saved and none were skipped.
  bool get allSaved => skippedIds.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaveShowupsResult &&
          savedCount == other.savedCount &&
          skippedIds.length == other.skippedIds.length &&
          _listEquals(skippedIds, other.skippedIds);

  bool _listEquals(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(savedCount, Object.hashAll(skippedIds));
}
