/// Talks to the sibling Checklister app via deep links (GH #464).
abstract interface class ChecklisterGateway {
  /// Whether Checklister is installed and can handle its URL scheme.
  Future<bool> isInstalled();

  /// Opens Checklister's checklist picker. Returns `false` if the link could not be opened.
  Future<bool> launchSelect(String callbackUrl);

  /// Opens Checklister to run [checklistId]. Returns `false` if the link could not be opened.
  Future<bool> launchRun(String checklistId, String callbackUrl);
}
