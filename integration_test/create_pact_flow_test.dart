// On-device entry point for the create-pact flow test.
//
// Run with: flutter test integration_test/create_pact_flow_test.dart -d <device>
//
// The test logic lives in test/app/flows/ and is shared with the host
// (CI-friendly) execution mode. This file simply bootstraps the
// IntegrationTestWidgetsFlutterBinding and delegates to the shared main().
import 'package:integration_test/integration_test.dart';

import '../test/app/flows/create_pact_flow_test.dart' as flow;
import '../test/app/harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppHarness.initForOnDevice();
  flow.main();
}
