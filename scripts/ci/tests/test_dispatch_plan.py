import unittest

from ci.dispatch_plan import dispatch_plan


class TestDispatchPlan(unittest.TestCase):

    # --- non-dispatch passthrough ---

    def test_push_event_forces_full_automatic_behaviour(self):
        """Any non-workflow_dispatch event always builds and distributes both platforms/channels."""
        result = dispatch_plan(event='push', android=False, ios=False, environment='staging')
        self.assertTrue(result['build_android'])
        self.assertTrue(result['build_ios'])
        self.assertTrue(result['distribute_android'])
        self.assertTrue(result['distribute_ios'])
        self.assertTrue(result['distribute_testflight'])
        self.assertEqual(result['group_alias'], 'internal-testers')

    def test_pull_request_event_forces_full_automatic_behaviour(self):
        result = dispatch_plan(event='pull_request', android=False, ios=False, environment='staging')
        self.assertTrue(result['build_android'])
        self.assertTrue(result['build_ios'])
        self.assertTrue(result['distribute_android'])
        self.assertTrue(result['distribute_ios'])
        self.assertTrue(result['distribute_testflight'])
        self.assertEqual(result['group_alias'], 'internal-testers')

    # --- workflow_dispatch: both platforms, production ---

    def test_dispatch_both_production(self):
        result = dispatch_plan(event='workflow_dispatch', android=True, ios=True, environment='production')
        self.assertTrue(result['build_android'])
        self.assertTrue(result['build_ios'])
        self.assertTrue(result['distribute_android'])
        self.assertTrue(result['distribute_ios'])
        self.assertTrue(result['distribute_testflight'])
        self.assertEqual(result['group_alias'], 'internal-testers')

    # --- workflow_dispatch: single platform ---

    def test_dispatch_android_only(self):
        result = dispatch_plan(event='workflow_dispatch', android=True, ios=False, environment='production')
        self.assertTrue(result['build_android'])
        self.assertFalse(result['build_ios'])
        self.assertTrue(result['distribute_android'])
        self.assertFalse(result['distribute_ios'])
        self.assertFalse(result['distribute_testflight'])

    def test_dispatch_ios_only(self):
        result = dispatch_plan(event='workflow_dispatch', android=False, ios=True, environment='production')
        self.assertFalse(result['build_android'])
        self.assertTrue(result['build_ios'])
        self.assertFalse(result['distribute_android'])
        self.assertTrue(result['distribute_ios'])
        self.assertTrue(result['distribute_testflight'])

    # --- workflow_dispatch: staging suppresses distribution ---

    def test_dispatch_staging_suppresses_distribution(self):
        """Distribution is always suppressed when environment is staging, regardless of the per-channel toggles."""
        result = dispatch_plan(event='workflow_dispatch', android=True, ios=True, environment='staging')
        self.assertTrue(result['build_android'])
        self.assertTrue(result['build_ios'])
        self.assertFalse(result['distribute_android'])
        self.assertFalse(result['distribute_ios'])
        self.assertFalse(result['distribute_testflight'])
        self.assertEqual(result['group_alias'], 'staging-testers')

    def test_dispatch_staging_android_only(self):
        result = dispatch_plan(event='workflow_dispatch', android=True, ios=False, environment='staging')
        self.assertTrue(result['build_android'])
        self.assertFalse(result['build_ios'])
        self.assertFalse(result['distribute_android'])
        self.assertFalse(result['distribute_ios'])
        self.assertFalse(result['distribute_testflight'])
        self.assertEqual(result['group_alias'], 'staging-testers')

    # --- workflow_dispatch: per-channel distribution toggles ---

    def test_dispatch_testflight_only(self):
        """distribute_firebase=False suppresses Firebase (both platforms) but not TestFlight."""
        result = dispatch_plan(
            event='workflow_dispatch', android=True, ios=True, environment='production',
            distribute_firebase=False, distribute_testflight=True,
        )
        self.assertFalse(result['distribute_android'])
        self.assertFalse(result['distribute_ios'])
        self.assertTrue(result['distribute_testflight'])

    def test_dispatch_firebase_only(self):
        """distribute_testflight=False suppresses TestFlight but not Firebase."""
        result = dispatch_plan(
            event='workflow_dispatch', android=True, ios=True, environment='production',
            distribute_firebase=True, distribute_testflight=False,
        )
        self.assertTrue(result['distribute_android'])
        self.assertTrue(result['distribute_ios'])
        self.assertFalse(result['distribute_testflight'])

    def test_dispatch_channel_toggles_default_true(self):
        """Omitting the toggles distributes to both channels."""
        result = dispatch_plan(event='workflow_dispatch', android=True, ios=True, environment='production')
        self.assertTrue(result['distribute_android'])
        self.assertTrue(result['distribute_ios'])
        self.assertTrue(result['distribute_testflight'])

    def test_dispatch_both_channels_off(self):
        """Turning off both toggles is the build-only run (equivalent to the old deploy=false)."""
        result = dispatch_plan(
            event='workflow_dispatch', android=True, ios=True, environment='production',
            distribute_firebase=False, distribute_testflight=False,
        )
        self.assertTrue(result['build_android'])
        self.assertTrue(result['build_ios'])
        self.assertFalse(result['distribute_android'])
        self.assertFalse(result['distribute_ios'])
        self.assertFalse(result['distribute_testflight'])

    # --- group_alias ---

    def test_production_group_alias(self):
        result = dispatch_plan(event='workflow_dispatch', android=True, ios=True, environment='production')
        self.assertEqual(result['group_alias'], 'internal-testers')

    def test_staging_group_alias(self):
        result = dispatch_plan(event='workflow_dispatch', android=True, ios=True, environment='staging')
        self.assertEqual(result['group_alias'], 'staging-testers')
