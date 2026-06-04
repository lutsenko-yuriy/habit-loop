import unittest
from unittest.mock import patch

import skill_router.__main__ as _main_mod
from .fixtures import (
    _FM_PLAIN,
    _FM_SESSION_TOOLS,
    _FM_NO_EFFORT,
    _FM_FOCUSED,
    _FM_WITH_CONTEXT,
    _FM_WITH_TOOLS_LINEAR,
    _FM_WITH_TOOLS_GITHUB,
)

_MOD = "skill_router.__main__"


class TestMain(unittest.TestCase):

    def _run(self, argv):
        with patch("sys.argv", argv):
            with self.assertRaises(SystemExit) as ctx:
                _main_mod.main()
        return ctx.exception.code

    def test_no_args_exits_2(self):
        self.assertEqual(self._run(["skill_router.py"]), 2)

    @patch("pathlib.Path.exists", return_value=False)
    def test_missing_skill_file_exits_2(self, _):
        self.assertEqual(self._run(["skill_router.py", "no/such/SKILL.md"]), 2)

    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_NO_EFFORT)
    @patch("pathlib.Path.exists", return_value=True)
    def test_unparseable_frontmatter_exits_2(self, *_):
        self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 2)

    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_SESSION_TOOLS)
    @patch("pathlib.Path.exists", return_value=True)
    def test_needs_session_tools_exits_2(self, *_):
        self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 2)

    @patch(f"{_MOD}.lookup_lmstudio_model", return_value=None)
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_FOCUSED)
    @patch("pathlib.Path.exists", return_value=True)
    def test_no_lmstudio_mapping_exits_2(self, *_):
        self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 2)

    @patch(f"{_MOD}.model_loaded", return_value=False)
    @patch(f"{_MOD}.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_PLAIN)
    @patch("pathlib.Path.exists", return_value=True)
    def test_model_not_loaded_exits_1(self, *_):
        self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 1)

    @patch(f"{_MOD}.stream_completion", return_value=False)
    @patch(f"{_MOD}.model_loaded", return_value=True)
    @patch(f"{_MOD}.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_PLAIN)
    @patch("pathlib.Path.exists", return_value=True)
    def test_stream_failure_exits_1(self, *_):
        self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 1)

    @patch(f"{_MOD}.stream_completion", return_value=True)
    @patch(f"{_MOD}.model_loaded", return_value=True)
    @patch(f"{_MOD}.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_PLAIN)
    @patch("pathlib.Path.exists", return_value=True)
    def test_success_does_not_exit(self, *_):
        with patch("sys.argv", ["skill_router.py", "fake/SKILL.md"]):
            _main_mod.main()  # must not raise

    @patch(f"{_MOD}.stream_completion")
    @patch(f"{_MOD}.model_loaded", return_value=True)
    @patch(f"{_MOD}.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_PLAIN)
    @patch("pathlib.Path.exists", return_value=True)
    def test_extra_args_appended_to_prompt(self, _exists, _fm, _model, _loaded, mock_stream):
        mock_stream.return_value = True
        with patch("sys.argv", ["skill_router.py", "fake/SKILL.md", "--args", "PR #42"]):
            _main_mod.main()
        call_prompt = mock_stream.call_args[0][1]
        self.assertIn("PR #42", call_prompt)
        self.assertIn("body", call_prompt)

    @patch(f"{_MOD}.stream_completion", return_value=True)
    @patch(f"{_MOD}.model_loaded", return_value=True)
    @patch(f"{_MOD}.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch(f"{_MOD}.fetch_linear_context", return_value={"issues": [], "milestones": []})
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_WITH_CONTEXT)
    @patch("pathlib.Path.exists", return_value=True)
    def test_context_linear_fetches_and_prepends(self, _exists, _fm, mock_fetch, _model, _loaded, mock_stream):
        with patch.dict("os.environ", {"LINEAR_API_KEY": "lin_api_test"}):
            with patch("sys.argv", ["skill_router.py", "fake/SKILL.md"]):
                _main_mod.main()
        mock_fetch.assert_called_once_with("lin_api_test")
        prompt = mock_stream.call_args[0][1]
        self.assertIn("PRE-FETCHED BACKLOG", prompt)
        self.assertIn("body", prompt)

    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_WITH_CONTEXT)
    @patch("pathlib.Path.exists", return_value=True)
    def test_context_linear_exits_2_without_api_key(self, *_):
        with patch.dict("os.environ", {}, clear=True):
            self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 2)

    @patch(f"{_MOD}.fetch_linear_context", side_effect=Exception("network error"))
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_WITH_CONTEXT)
    @patch("pathlib.Path.exists", return_value=True)
    def test_context_linear_exits_1_on_fetch_error(self, *_):
        with patch.dict("os.environ", {"LINEAR_API_KEY": "lin_api_test"}):
            self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 1)

    @patch(f"{_MOD}.chat_completion_with_tools", return_value=True)
    @patch(f"{_MOD}.model_loaded", return_value=True)
    @patch(f"{_MOD}.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_WITH_TOOLS_GITHUB)
    @patch("pathlib.Path.exists", return_value=True)
    def test_tools_dispatches_to_chat_completion(self, _exists, _fm, _model, _loaded, mock_chat):
        with patch("sys.argv", ["skill_router.py", "fake/SKILL.md"]):
            _main_mod.main()
        mock_chat.assert_called_once()
        _, _, tools = mock_chat.call_args[0]
        tool_names = [t["function"]["name"] for t in tools]
        self.assertIn("github_get_pr", tool_names)
        self.assertIn("read_file", tool_names)

    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_WITH_TOOLS_LINEAR)
    @patch("pathlib.Path.exists", return_value=True)
    def test_tools_linear_exits_2_without_api_key(self, *_):
        with patch.dict("os.environ", {}, clear=True):
            self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 2)

    @patch(f"{_MOD}.stream_completion", return_value=True)
    @patch(f"{_MOD}.model_loaded", return_value=True)
    @patch(f"{_MOD}.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_PLAIN)
    @patch("pathlib.Path.exists", return_value=True)
    def test_no_tools_uses_stream_completion(self, _exists, _fm, _model, _loaded, mock_stream):
        mock_stream.return_value = True
        with patch("sys.argv", ["skill_router.py", "fake/SKILL.md"]):
            _main_mod.main()
        mock_stream.assert_called_once()

    @patch(f"{_MOD}.stream_completion")
    @patch(f"{_MOD}.model_loaded", return_value=True)
    @patch(f"{_MOD}.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch(f"{_MOD}.read_frontmatter", return_value=_FM_PLAIN)
    @patch("pathlib.Path.exists", return_value=True)
    def test_api_model_name_is_normalized(self, _exists, _fm, _model, _loaded, mock_stream):
        mock_stream.return_value = True
        with patch("sys.argv", ["skill_router.py", "fake/SKILL.md"]):
            _main_mod.main()
        api_model = mock_stream.call_args[0][0]
        self.assertNotIn("(", api_model)
        self.assertEqual(api_model, "qwen/qwen3-8b")


if __name__ == "__main__":
    unittest.main()
