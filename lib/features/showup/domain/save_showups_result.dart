/// Result of a bulk [saveShowups] operation.
class SaveShowupsResult {
  /// Number of showups that were successfully saved.
  final int savedCount;

  /// IDs of showups that were skipped because they already existed.
  final List<String> skippedIds;

  const SaveShowupsResult({
    required this.savedCount,
    required this.skippedIds,
  });

  /// True if all showups were saved and none were skipped.
  bool get allSaved => skippedIds.isEmpty;
}
