class SaveShowupsResult {
  final int savedCount;
  final List<String> skippedIds;

  SaveShowupsResult({
    required this.savedCount,
    required List<String> skippedIds,
  }) : skippedIds = List.unmodifiable(skippedIds);

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
