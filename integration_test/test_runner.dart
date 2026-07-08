// Single entry point that combines all integration test suites.
//
// Run with:
//   flutter test integration_test/test_runner.dart -d <device>
//
// This installs the APK / .app once and runs every suite in sequence,
// avoiding the ~16 s per-file reinstall cost that `flutter test
// integration_test/` incurs on Android.
import 'package:integration_test/integration_test.dart';

import 'about_screen_flow_test.dart' as about;
import 'archive_pact_flow_test.dart' as archive_pact;
import 'create_pact_flow_test.dart' as create_pact;
import 'dashboard_kebab_menu_flow_test.dart' as kebab_menu;
import 'edit_pact_flow_test.dart' as edit_pact;
import 'fake_firestore_sync_flow_test.dart' as fake_firestore;
import 'fresh_install_flow_test.dart' as fresh_install;
import 'language_change_flow_test.dart' as language_change;
import 'mark_showup_done_flow_test.dart' as mark_showup_done;
import 'notification_navigation_flow_test.dart' as notification_nav;
import 'onboarding_carousel_flow_test.dart' as onboarding;
import 'pact_note_flow_test.dart' as pact_note;
import 'pact_timeline_flow_test.dart' as pact_timeline;
import 'redeem_showup_flow_test.dart' as redeem_showup;
import 'remote_config_overrides_flow_test.dart' as remote_config_overrides;
import 'showup_to_pact_navigation_flow_test.dart' as showup_to_pact;
import 'stop_pact_flow_test.dart' as stop_pact;
import 'sync_on_login_flow_test.dart' as sync_on_login;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  about.main();
  archive_pact.main();
  create_pact.main();
  kebab_menu.main();
  edit_pact.main();
  fake_firestore.main();
  fresh_install.main();
  language_change.main();
  mark_showup_done.main();
  notification_nav.main();
  onboarding.main();
  pact_note.main();
  pact_timeline.main();
  redeem_showup.main();
  remote_config_overrides.main();
  showup_to_pact.main();
  stop_pact.main();
  sync_on_login.main();
}
