import unittest

from ci.dispatch_plan import dispatch_plan


class TestDispatchPlan(unittest.TestCase):

    # --- non-dispatch passthrough ---

    def test_push_event_forces_full_automatic_behaviour(self):
        """Any non-workflow_dispatch event always builds and deploys both platforms."""
        result = dispatch_plan(event='push', android=False, ios=False, deploy=False, environment='staging')
        self.assertTrue(result['build_android'])
        self.assertTrue(result['build_ios'])
        self.assertTrue(result['distribute_android'])
        self.assertTrue(result['distribute_ios'])
        self.assertTrue(result['distribute_testflight'])
        self.assertEqual(result['group_alias'], 'internal-testers')

    def test_pull_request_event_forces_full_automatic_behaviour(self):
        result = dispatch_plan(event='pull_request', android=False, ios=False, deploy=False, environment='staging')
        self.assertTrue(result['build_android'])
        self.assertTrue(result['build_ios'])
        self.assertTrue(result['distribute_android'])
        self.assertTrue(result['distribute_ios'])
        self.assertTrue(result['distribute_testflight'])
        self.assertEqual(result['group_alias'], 'internal-testers')

    # --- workflow_dispatch: both platforms, production ---

    def test_dispatch_both_deploy_production(self):
        result = dispatch_plan(event='workflow_dispatch', android=True, ios=True, deploy=True, environment='production')
        self.assertTrue(result['build_android'])
        self.assertTrue(result['build_ios'])
        self.assertTrue(result['distribute_android'])
        self.assertTrue(result['distribute_ios'])
        self.assertTrue(result['distribute_testflight'])
        self.assertEqual(result['group_alias'], 'internal-testers')

    # --- workflow_dispatch: single platform ---

    def test_dispatch_android_only(self):
        result = dispatch_plan(event='workflow_dispatch', android=True, ios=False, deploy=True, environment='production')
        self.assertTrue(result['build_android'])
        self.assertFalse(result['build_ios'])
        self.assertTrue(result['distribute_android'])
        self.assertFalse(result['distribute_ios'])
        self.assertFalse(result['distribute_testflight'])

    def test_dispatch_ios_only(self):
        result = dispatch_plan(event='workflow_dispatch', android=False, ios=True, deploy=True, environment='production')
        self.assertFalse(result['build_android'])
        self.assertTrue(result['build_ios'])
        self.assertFalse(result['distribute_android'])
        self.assertTrue(result['distribute_ios'])
        self.assertTrue(result['distribute_testflight'])

    # --- workflow_dispatch: build-only (deploy=false) ---

    def test_dispatch_both_no_deploy(self):
        result = dispatch_plan(event='workflow_dispatch', android=True, ios=True, deploy=False, environment='production')
        self.assertTrue(result['build_android'])
        self.assertTrue(result['build_ios'])
        self.assertFalse(result['distribute_android'])
        self.assertFalse(result['distribute_ios'])
        self.assertFalse(result['distribute_testflight'])

    def test_dispatch_android_only_no_deploy(self):
        result = dispatch_plan(event='workflow_dispatch', android=True, ios=False, deploy=False, environment='production')
        self.assertTrue(result['build_android'])
        self.assertFalse(result['build_ios'])
        self.assertFalse(result['distribute_android'])
        self.assertFalse(result['distribute_ios'])
        self.assertFalse(result['distribute_testflight'])

    # --- workflow_dispatch: staging overrides deploy ---

    def test_dispatch_staging_suppresses_distribution(self):
        """deploy=True is ignored when environment is staging."""
        result = dispatch_plan(event='workflow_dispatch', android=True, ios=True, deploy=True, environment='staging')
        self.assertTrue(result['build_android'])
        self.assertTrue(result['build_ios'])
        self.assertFalse(result['distribute_android'])
        self.assertFalse(result['distribute_ios'])
        self.assertFalse(result['distribute_testflight'])
        self.assertEqual(result['group_alias'], 'staging-testers')

    def test_dispatch_staging_android_only(self):
        result = dispatch_plan(event='workflow_dispatch', android=True, ios=False, deploy=True, environment='staging')
        self.assertTrue(result['build_android'])
        self.assertFalse(result['build_ios'])
        self.assertFalse(result['distribute_android'])
        self.assertFalse(result['distribute_ios'])
        self.assertFalse(result['distribute_testflight'])
        self.assertEqual(result['group_alias'], 'staging-testers')

    # --- workflow_dispatch: distribute_testflight mirrors distribute_ios ---

    def test_dispatch_testflight_ios_only_not_deployed(self):
        """distribute_testflight follows the same ios+deploy+production gating as distribute_ios."""
        result = dispatch_plan(event='workflow_dispatch', android=False, ios=True, deploy=False, environment='production')
        self.assertFalse(result['distribute_ios'])
        self.assertFalse(result['distribute_testflight'])

    # --- group_alias ---

    def test_production_group_alias(self):
        result = dispatch_plan(event='workflow_dispatch', android=True, ios=True, deploy=True, environment='production')
        self.assertEqual(result['group_alias'], 'internal-testers')

    def test_staging_group_alias(self):
        result = dispatch_plan(event='workflow_dispatch', android=True, ios=True, deploy=False, environment='staging')
        self.assertEqual(result['group_alias'], 'staging-testers')
