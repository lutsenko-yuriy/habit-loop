// On-device entry point for the language-change flow test.
//
// Run with: flutter test integration_test/language_change_flow_test.dart -d <device>
import 'package:integration_test/integration_test.dart';

import '../test/app/flows/language_change_flow_test.dart' as flow;
import '../test/app/harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppHarness.initForOnDevice();
  flow.main();
}
