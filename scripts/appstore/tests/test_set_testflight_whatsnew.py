import base64
import os
import unittest
import urllib.error
from unittest import mock

import jwt
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec

from appstore import set_testflight_whatsnew as sut


def _generate_ec_keypair():
    """Return (private_key_pem_bytes, public_key_object) for an ES256 test key."""
    private_key = ec.generate_private_key(ec.SECP256R1())
    private_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    return private_pem, private_key.public_key()


class TestBuildJwt(unittest.TestCase):

    def setUp(self):
        self.private_pem, self.public_key = _generate_ec_keypair()

    def test_token_is_verifiable_and_has_correct_claims(self):
        token = sut.build_jwt("issuer-123", "KEY123", self.private_pem)

        header = jwt.get_unverified_header(token)
        self.assertEqual(header["alg"], "ES256")
        self.assertEqual(header["kid"], "KEY123")

        decoded = jwt.decode(token, self.public_key, algorithms=["ES256"], audience="appstore-connect-v1")
        self.assertEqual(decoded["iss"], "issuer-123")
        self.assertEqual(decoded["aud"], "appstore-connect-v1")
        self.assertIn("iat", decoded)
        self.assertIn("exp", decoded)

    def test_expiry_is_within_apples_20_minute_limit(self):
        token = sut.build_jwt("issuer-123", "KEY123", self.private_pem)
        decoded = jwt.decode(token, self.public_key, algorithms=["ES256"], audience="appstore-connect-v1")
        lifetime = decoded["exp"] - decoded["iat"]
        self.assertGreater(lifetime, 0)
        self.assertLessEqual(lifetime, 20 * 60)


class TestResolveAppId(unittest.TestCase):

    @mock.patch.object(sut, "_request")
    def test_returns_id_of_first_matching_app(self, mock_request):
        mock_request.return_value = {"data": [{"id": "app-42", "type": "apps"}]}
        app_id = sut.resolve_app_id("token")
        self.assertEqual(app_id, "app-42")
        args, kwargs = mock_request.call_args
        self.assertEqual(args[0], "GET")
        self.assertIn("filter[bundleId]=com.habitloop.habitLoop", args[1])

    @mock.patch.object(sut, "_request")
    def test_raises_when_no_app_found(self, mock_request):
        mock_request.return_value = {"data": []}
        with self.assertRaises(LookupError):
            sut.resolve_app_id("token")


class TestPollBuild(unittest.TestCase):

    @mock.patch.object(sut, "_request")
    def test_returns_build_once_processing_state_is_valid(self, mock_request):
        mock_request.side_effect = [
            {"data": [{"id": "build-1", "attributes": {"processingState": "PROCESSING"}}]},
            {"data": [{"id": "build-1", "attributes": {"processingState": "VALID"}}]},
        ]
        sleeps = []
        clock = mock.Mock(side_effect=[0, 0, 1])  # deadline calc, loop check 1, loop check 2

        build = sut.poll_build(
            lambda: "token", "app-1", "42", "1.2.3",
            timeout_seconds=100, interval_seconds=1,
            sleep_fn=sleeps.append, clock=clock,
        )

        self.assertIsNotNone(build)
        self.assertEqual(build["id"], "build-1")
        self.assertEqual(mock_request.call_count, 2)
        self.assertEqual(sleeps, [1])

    @mock.patch.object(sut, "_request")
    def test_keeps_polling_while_processing(self, mock_request):
        mock_request.side_effect = [
            {"data": [{"id": "build-1", "attributes": {"processingState": "PROCESSING"}}]},
            {"data": [{"id": "build-1", "attributes": {"processingState": "PROCESSING"}}]},
            {"data": [{"id": "build-1", "attributes": {"processingState": "VALID"}}]},
        ]
        sleeps = []
        clock = mock.Mock(side_effect=[0, 0, 1, 2])

        build = sut.poll_build(
            lambda: "token", "app-1", "42", "1.2.3",
            timeout_seconds=100, interval_seconds=1,
            sleep_fn=sleeps.append, clock=clock,
        )

        self.assertIsNotNone(build)
        self.assertEqual(mock_request.call_count, 3)

    @mock.patch.object(sut, "_request")
    def test_handles_empty_result_set_without_crashing(self, mock_request):
        mock_request.side_effect = [
            {"data": []},
            {"data": [{"id": "build-1", "attributes": {"processingState": "VALID"}}]},
        ]
        sleeps = []
        clock = mock.Mock(side_effect=[0, 0, 1])

        build = sut.poll_build(
            lambda: "token", "app-1", "42", "1.2.3",
            timeout_seconds=100, interval_seconds=1,
            sleep_fn=sleeps.append, clock=clock,
        )

        self.assertIsNotNone(build)

    @mock.patch.object(sut, "_request")
    def test_returns_none_on_timeout_instead_of_raising(self, mock_request):
        mock_request.return_value = {
            "data": [{"id": "build-1", "attributes": {"processingState": "PROCESSING"}}]
        }
        sleeps = []
        # deadline = 0 + 5 = 5; loop checks: 0 (start, < 5, sleep), 6 (>= 5, stop)
        clock = mock.Mock(side_effect=[0, 0, 6])

        build = sut.poll_build(
            lambda: "token", "app-1", "42", "1.2.3",
            timeout_seconds=5, interval_seconds=1,
            sleep_fn=sleeps.append, clock=clock,
        )

        self.assertIsNone(build)

    @mock.patch.object(sut, "_request")
    def test_requests_a_fresh_token_on_every_iteration(self, mock_request):
        """The App Store Connect JWT lives 15 min but a poll can run up to 30 min —
        each request must use a freshly minted token, not one captured at the start."""
        mock_request.side_effect = [
            {"data": [{"id": "build-1", "attributes": {"processingState": "PROCESSING"}}]},
            {"data": [{"id": "build-1", "attributes": {"processingState": "VALID"}}]},
        ]
        sleeps = []
        clock = mock.Mock(side_effect=[0, 0, 1])
        token_provider = mock.Mock(side_effect=["token-1", "token-2"])

        sut.poll_build(
            token_provider, "app-1", "42", "1.2.3",
            timeout_seconds=100, interval_seconds=1,
            sleep_fn=sleeps.append, clock=clock,
        )

        self.assertEqual(token_provider.call_count, 2)
        used_tokens = [call.args[2] for call in mock_request.call_args_list]
        self.assertEqual(used_tokens, ["token-1", "token-2"])

    @mock.patch.object(sut, "_request")
    def test_stops_early_on_terminal_failure_state(self, mock_request):
        mock_request.return_value = {
            "data": [{"id": "build-1", "attributes": {"processingState": "INVALID"}}]
        }
        sleeps = []
        clock = mock.Mock(side_effect=[0, 0])

        build = sut.poll_build(
            lambda: "token", "app-1", "42", "1.2.3",
            timeout_seconds=100, interval_seconds=1,
            sleep_fn=sleeps.append, clock=clock,
        )

        self.assertIsNone(build)
        self.assertEqual(mock_request.call_count, 1)
        self.assertEqual(sleeps, [])  # returned immediately, never slept

    @mock.patch.object(sut, "_request")
    def test_retries_after_a_transient_request_error(self, mock_request):
        mock_request.side_effect = [
            urllib.error.URLError("connection reset"),
            {"data": [{"id": "build-1", "attributes": {"processingState": "VALID"}}]},
        ]
        sleeps = []
        clock = mock.Mock(side_effect=[0, 0, 1])

        build = sut.poll_build(
            lambda: "token", "app-1", "42", "1.2.3",
            timeout_seconds=100, interval_seconds=1,
            sleep_fn=sleeps.append, clock=clock,
        )

        self.assertIsNotNone(build)
        self.assertEqual(mock_request.call_count, 2)
        self.assertEqual(sleeps, [1])


class TestUpsertBetaBuildLocalization(unittest.TestCase):

    @mock.patch.object(sut, "_request")
    def test_patches_existing_localization(self, mock_request):
        mock_request.side_effect = [
            {"data": [{"id": "loc-1", "attributes": {"locale": "en-US"}}]},  # GET
            {"data": {"id": "loc-1"}},  # PATCH
        ]

        sut.upsert_beta_build_localization("token", "build-1", "Bug fixes and improvements.")

        self.assertEqual(mock_request.call_count, 2)
        patch_call = mock_request.call_args_list[1]
        method, url = patch_call.args[0], patch_call.args[1]
        self.assertEqual(method, "PATCH")
        self.assertIn("betaBuildLocalizations/loc-1", url)
        payload = patch_call.kwargs["data"]
        self.assertEqual(payload["data"]["attributes"]["whatsNew"], "Bug fixes and improvements.")

    @mock.patch.object(sut, "_request")
    def test_posts_new_localization_when_none_exists(self, mock_request):
        mock_request.side_effect = [
            {"data": []},  # GET — no existing localization
            {"data": {"id": "loc-new"}},  # POST
        ]

        sut.upsert_beta_build_localization("token", "build-1", "Bug fixes and improvements.")

        self.assertEqual(mock_request.call_count, 2)
        post_call = mock_request.call_args_list[1]
        method, url = post_call.args[0], post_call.args[1]
        self.assertEqual(method, "POST")
        self.assertTrue(url.endswith("/betaBuildLocalizations"))
        payload = post_call.kwargs["data"]
        self.assertEqual(payload["data"]["attributes"]["whatsNew"], "Bug fixes and improvements.")
        self.assertEqual(payload["data"]["attributes"]["locale"], "en-US")
        self.assertEqual(payload["data"]["relationships"]["build"]["data"]["id"], "build-1")


class TestMain(unittest.TestCase):

    def setUp(self):
        self.env = {
            "APP_STORE_CONNECT_ISSUER_ID": "issuer-1",
            "APP_STORE_CONNECT_KEY_ID": "key-1",
            "APP_STORE_CONNECT_API_KEY_P8": base64.b64encode(b"fake-key-material").decode(),
            "BUILD_NUMBER": "42",
            "VERSION_NAME": "1.2.3",
            "RELEASE_NOTES": "New stuff.",
        }

    @mock.patch.object(sut, "upsert_beta_build_localization")
    @mock.patch.object(sut, "poll_build")
    @mock.patch.object(sut, "resolve_app_id")
    @mock.patch.object(sut, "build_jwt")
    def test_happy_path_updates_whats_new_and_exits_zero(
        self, mock_build_jwt, mock_resolve_app_id, mock_poll_build, mock_upsert
    ):
        mock_build_jwt.return_value = "jwt-token"
        mock_resolve_app_id.return_value = "app-1"
        mock_poll_build.return_value = {"id": "build-1"}

        with mock.patch.dict(os.environ, self.env, clear=True):
            exit_code = sut.main()

        self.assertEqual(exit_code, 0)
        mock_upsert.assert_called_once_with("jwt-token", "build-1", "New stuff.")

    @mock.patch.object(sut, "poll_build")
    @mock.patch.object(sut, "resolve_app_id")
    @mock.patch.object(sut, "build_jwt")
    def test_soft_fails_and_exits_zero_when_build_never_becomes_valid(
        self, mock_build_jwt, mock_resolve_app_id, mock_poll_build
    ):
        mock_build_jwt.return_value = "jwt-token"
        mock_resolve_app_id.return_value = "app-1"
        mock_poll_build.return_value = None  # timed out

        with mock.patch.dict(os.environ, self.env, clear=True):
            exit_code = sut.main()

        self.assertEqual(exit_code, 0)

    @mock.patch.object(sut, "resolve_app_id")
    @mock.patch.object(sut, "build_jwt")
    def test_soft_fails_and_exits_zero_on_api_error(self, mock_build_jwt, mock_resolve_app_id):
        mock_build_jwt.return_value = "jwt-token"
        mock_resolve_app_id.side_effect = RuntimeError("API is down")

        with mock.patch.dict(os.environ, self.env, clear=True):
            exit_code = sut.main()

        self.assertEqual(exit_code, 0)

    def test_missing_required_env_var_returns_nonzero(self):
        incomplete_env = dict(self.env)
        del incomplete_env["BUILD_NUMBER"]

        with mock.patch.dict(os.environ, incomplete_env, clear=True):
            exit_code = sut.main()

        self.assertEqual(exit_code, 1)

    @mock.patch.object(sut, "upsert_beta_build_localization")
    @mock.patch.object(sut, "poll_build")
    @mock.patch.object(sut, "resolve_app_id")
    @mock.patch.object(sut, "build_jwt")
    def test_skips_upsert_when_release_notes_blank(
        self, mock_build_jwt, mock_resolve_app_id, mock_poll_build, mock_upsert
    ):
        mock_build_jwt.return_value = "jwt-token"
        mock_resolve_app_id.return_value = "app-1"
        mock_poll_build.return_value = {"id": "build-1"}
        blank_env = dict(self.env, RELEASE_NOTES="   ")

        with mock.patch.dict(os.environ, blank_env, clear=True):
            exit_code = sut.main()

        self.assertEqual(exit_code, 0)
        mock_upsert.assert_not_called()


if __name__ == "__main__":
    unittest.main()
