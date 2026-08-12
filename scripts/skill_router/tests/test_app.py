import os
import unittest
from unittest.mock import MagicMock, patch

from skill_router.app import run
from skill_router.config import Config
from .fixtures import (
    _FM_PLAIN,
    _FM_SESSION_TOOLS,
    _FM_NO_EFFORT,
    _FM_FOCUSED,
    _FM_WITH_CONTEXT,
    _FM_WITH_TOOLS_LINEAR,
    _FM_WITH_TOOLS_GITHUB,
)

_MOD = "skill_router.app"


def _fake_load_config(toml_path="skill_router.toml"):
    """Build a Config from current os.environ (so tests that patch.dict
    os.environ still see the effect), but pinned to local_models_enabled=True
    regardless of the real skill_router.toml on disk — most tests here predate
    that gate and never intended to exercise it."""
    return Config(
        linear_api_key=os.environ.get("LINEAR_API_KEY"),
        linear_project_id=os.environ.get("LINEAR_PROJECT_ID"),
        lmstudio_base=os.environ.get("LMSTUDIO_BASE", "http://localhost:1234/v1"),
        model_tiers_path="docs/MODEL_TIERS.md",
        local_models_enabled=True,
    )


class TestRun(unittest.TestCase):

    def setUp(self):
        patcher = patch(f"{_MOD}.load_config", side_effect=_fake_load_config)
        patcher.start()
        self.addCleanup(patcher.stop)

    def _run(self, argv):
        return run(argv)

    def test_no_args_returns_2(self):
        self.assertEqual(self._run(["skill_router"]), 2)

    @patch("pathlib.Path.exists", return_value=False)
    def test_missing_skill_file_returns_2(self, _):
        self.assertEqual(self._run(["skill_router", "no/such/SKILL.md"]), 2)

    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_NO_EFFORT)
    @patch("pathlib.Path.exists", return_value=True)
    def test_unparseable_frontmatter_returns_2(self, *_):
        self.assertEqual(self._run(["skill_router", "fake/SKILL.md"]), 2)

    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_SESSION_TOOLS)
    @patch("pathlib.Path.exists", return_value=True)
    def test_needs_session_tools_returns_2(self, *_):
        self.assertEqual(self._run(["skill_router", "fake/SKILL.md"]), 2)

    @patch(f"{_MOD}.lookup_lmstudio_model", return_value=None)
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_FOCUSED)
    @patch("pathlib.Path.exists", return_value=True)
    def test_no_lmstudio_mapping_returns_2(self, *_):
        self.assertEqual(self._run(["skill_router", "fake/SKILL.md"]), 2)

    @patch(f"{_MOD}.model_loaded", return_value=False)
    @patch(f"{_MOD}.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_PLAIN)
    @patch("pathlib.Path.exists", return_value=True)
    def test_model_not_loaded_returns_1(self, *_):
        self.assertEqual(self._run(["skill_router", "fake/SKILL.md"]), 1)

    @patch(f"{_MOD}.stream_completion", return_value=False)
    @patch(f"{_MOD}.model_loaded", return_value=True)
    @patch(f"{_MOD}.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_PLAIN)
    @patch("pathlib.Path.exists", return_value=True)
    def test_stream_failure_returns_1(self, *_):
        self.assertEqual(self._run(["skill_router", "fake/SKILL.md"]), 1)

    @patch(f"{_MOD}.stream_completion", return_value=True)
    @patch(f"{_MOD}.model_loaded", return_value=True)
    @patch(f"{_MOD}.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_PLAIN)
    @patch("pathlib.Path.exists", return_value=True)
    def test_success_returns_0(self, *_):
        self.assertEqual(self._run(["skill_router", "fake/SKILL.md"]), 0)

    @patch(f"{_MOD}.stream_completion")
    @patch(f"{_MOD}.model_loaded", return_value=True)
    @patch(f"{_MOD}.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_PLAIN)
    @patch("pathlib.Path.exists", return_value=True)
    def test_extra_args_appended_to_prompt(self, _exists, _fm, _model, _loaded, mock_stream):
        mock_stream.return_value = True
        self._run(["skill_router", "fake/SKILL.md", "--args", "PR #42"])
        call_prompt = mock_stream.call_args[0][1]
        self.assertIn("PR #42", call_prompt)
        self.assertIn("body", call_prompt)

    @patch(f"{_MOD}.stream_completion", return_value=True)
    @patch(f"{_MOD}.model_loaded", return_value=True)
    @patch(f"{_MOD}.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_WITH_CONTEXT)
    @patch("pathlib.Path.exists", return_value=True)
    def test_context_linear_fetches_and_prepends(self, _exists, _fm, _model, _loaded, mock_stream):
        # Inject a fake LinearProvider via the factory map so context fetch + format are observable.
        fake_provider = MagicMock()
        fake_provider.validate.return_value = None
        fake_provider.fetch_context.return_value = {"issues": [], "milestones": []}
        fake_provider.format_context.return_value = "=== PRE-FETCHED BACKLOG ===\nstuff\n=== END ==="
        fake_factory = MagicMock(return_value=fake_provider)
        with patch.dict(f"{_MOD}._PROVIDER_FACTORIES", {"linear": fake_factory}):
            with patch.dict("os.environ", {"LINEAR_API_KEY": "lin_api_test"}):
                self._run(["skill_router", "fake/SKILL.md"])
        fake_provider.fetch_context.assert_called_once()
        prompt = mock_stream.call_args[0][1]
        self.assertIn("PRE-FETCHED BACKLOG", prompt)
        self.assertIn("body", prompt)

    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_WITH_CONTEXT)
    @patch("pathlib.Path.exists", return_value=True)
    def test_context_linear_returns_2_without_api_key(self, *_):
        with patch.dict("os.environ", {}, clear=True):
            self.assertEqual(self._run(["skill_router", "fake/SKILL.md"]), 2)

    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_WITH_CONTEXT)
    @patch("pathlib.Path.exists", return_value=True)
    def test_context_linear_returns_1_on_fetch_error(self, *_):
        fake_provider = MagicMock()
        fake_provider.validate.return_value = None
        fake_provider.fetch_context.side_effect = Exception("network error")
        fake_factory = MagicMock(return_value=fake_provider)
        with patch.dict(f"{_MOD}._PROVIDER_FACTORIES", {"linear": fake_factory}):
            with patch.dict("os.environ", {"LINEAR_API_KEY": "lin_api_test"}):
                self.assertEqual(self._run(["skill_router", "fake/SKILL.md"]), 1)

    @patch(f"{_MOD}.chat_completion_with_tools", return_value=True)
    @patch(f"{_MOD}.model_loaded", return_value=True)
    @patch(f"{_MOD}.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_WITH_TOOLS_GITHUB)
    @patch("pathlib.Path.exists", return_value=True)
    def test_tools_dispatches_to_chat_completion(self, _exists, _fm, _model, _loaded, mock_chat):
        self._run(["skill_router", "fake/SKILL.md"])
        mock_chat.assert_called_once()
        # third positional arg is the registry
        registry = mock_chat.call_args[0][2]
        tool_names = [s["function"]["name"] for s in registry.tool_schemas()]
        self.assertIn("github_get_pr", tool_names)
        self.assertIn("read_file", tool_names)

    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_WITH_TOOLS_LINEAR)
    @patch("pathlib.Path.exists", return_value=True)
    def test_tools_linear_returns_2_without_api_key(self, *_):
        with patch.dict("os.environ", {}, clear=True):
            self.assertEqual(self._run(["skill_router", "fake/SKILL.md"]), 2)

    @patch(f"{_MOD}.stream_completion", return_value=True)
    @patch(f"{_MOD}.model_loaded", return_value=True)
    @patch(f"{_MOD}.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_PLAIN)
    @patch("pathlib.Path.exists", return_value=True)
    def test_no_tools_uses_stream_completion(self, _exists, _fm, _model, _loaded, mock_stream):
        mock_stream.return_value = True
        self._run(["skill_router", "fake/SKILL.md"])
        mock_stream.assert_called_once()

    @patch(f"{_MOD}.model_loaded")
    @patch(f"{_MOD}.load_config", return_value=MagicMock(local_models_enabled=False))
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_PLAIN)
    @patch("pathlib.Path.exists", return_value=True)
    def test_local_models_disabled_returns_1_without_touching_lmstudio(self, _exists, _fm, _cfg, mock_model_loaded):
        self.assertEqual(self._run(["skill_router", "fake/SKILL.md"]), 1)
        mock_model_loaded.assert_not_called()

    @patch(f"{_MOD}.stream_completion", return_value=True)
    @patch(f"{_MOD}.model_loaded", return_value=True)
    @patch(f"{_MOD}.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_PLAIN)
    @patch("pathlib.Path.exists", return_value=True)
    def test_local_models_enabled_proceeds_as_normal(self, *_):
        self.assertEqual(self._run(["skill_router", "fake/SKILL.md"]), 0)

    @patch(f"{_MOD}.stream_completion")
    @patch(f"{_MOD}.model_loaded", return_value=True)
    @patch(f"{_MOD}.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_PLAIN)
    @patch("pathlib.Path.exists", return_value=True)
    def test_api_model_name_is_normalized(self, _exists, _fm, _model, _loaded, mock_stream):
        mock_stream.return_value = True
        self._run(["skill_router", "fake/SKILL.md"])
        api_model = mock_stream.call_args[0][0]
        self.assertNotIn("(", api_model)
        self.assertEqual(api_model, "qwen/qwen3-8b")


if __name__ == "__main__":
    unittest.main()
