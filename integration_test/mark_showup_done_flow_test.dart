// On-device entry point for the mark-showup-done flow test.
//
// Run with: flutter test integration_test/mark_showup_done_flow_test.dart -d <device>
import 'package:integration_test/integration_test.dart';

import '../test/app/flows/mark_showup_done_flow_test.dart' as flow;
import '../test/app/harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppHarness.initForOnDevice();
  flow.main();
}
