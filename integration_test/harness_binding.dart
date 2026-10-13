import 'package:integration_test/integration_test.dart';

/// Integration binding that routes text input through flutter_test's fake keyboard.
///
/// The stock binding keeps the device's real IME attached, and `tester.enterText`
/// bypasses it — the IME's next stale update can revert the field (GH-474).
class HarnessBinding extends IntegrationTestWidgetsFlutterBinding {
  @override
  bool get registerTestTextInput => true;

  static HarnessBinding? _instance;

  /// Use instead of [IntegrationTestWidgetsFlutterBinding.ensureInitialized] in every scenario entry point.
  static HarnessBinding ensureInitialized() => _instance ??= HarnessBinding();
}
