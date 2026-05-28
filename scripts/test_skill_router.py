#!/usr/bin/env python3
"""Unit tests for skill_router.py — run with: python3 scripts/test_skill_router.py"""

import io
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).parent))
import skill_router

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

TIERS_MD_WITH_LMSTUDIO = """\
## Active mapping

| Effort | Reasoning | Model | Claude Code alias |
|---|---|---|---|
| THOROUGH | ARCHITECTURAL | claude-opus-4-6 | `opus` |
| RAPID | MECHANICAL | qwen/qwen3-8b (MLX, 4-bit) | `lm-studio` |
| FOCUSED | ARCHITECTURAL | claude-sonnet-4-6 | `sonnet` |

---
"""

SKILL_CONTENT_PLAIN = "---\neffort: RAPID\nreasoning: MECHANICAL\n---\nDo the thing.\n"
SKILL_CONTENT_NEEDS_MCP = "---\neffort: RAPID\nreasoning: MECHANICAL\nneeds_mcp: true\n---\nDo the thing.\n"
SKILL_CONTENT_NO_FM = "No frontmatter here."


# ---------------------------------------------------------------------------
# _normalize_model_name
# ---------------------------------------------------------------------------

class TestNormalizeModelName(unittest.TestCase):

    def test_strips_parenthetical_quantization(self):
        self.assertEqual(skill_router._normalize_model_name("qwen/qwen3-8b (MLX, 4-bit)"), "qwen/qwen3-8b")

    def test_strips_after_first_space(self):
        self.assertEqual(skill_router._normalize_model_name("mistralai/devstral-small 4bit"), "mistralai/devstral-small")

    def test_lowercases(self):
        self.assertEqual(skill_router._normalize_model_name("Qwen/Qwen3-8B"), "qwen/qwen3-8b")

    def test_plain_name_unchanged(self):
        self.assertEqual(skill_router._normalize_model_name("qwen/qwen3-8b"), "qwen/qwen3-8b")

    def test_strips_leading_trailing_whitespace(self):
        self.assertEqual(skill_router._normalize_model_name("  qwen/qwen3-8b  "), "qwen/qwen3-8b")


# ---------------------------------------------------------------------------
# read_frontmatter
# ---------------------------------------------------------------------------

class TestReadFrontmatter(unittest.TestCase):

    def _parse(self, content):
        with patch("pathlib.Path.read_text", return_value=content):
            return skill_router.read_frontmatter("fake/SKILL.md")

    def test_parses_effort_and_reasoning(self):
        effort, reasoning, needs_mcp, body = self._parse(SKILL_CONTENT_PLAIN)
        self.assertEqual(effort, "RAPID")
        self.assertEqual(reasoning, "MECHANICAL")

    def test_needs_mcp_false_by_default(self):
        _, _, needs_mcp, _ = self._parse(SKILL_CONTENT_PLAIN)
        self.assertFalse(needs_mcp)

    def test_needs_mcp_true_when_set(self):
        _, _, needs_mcp, _ = self._parse(SKILL_CONTENT_NEEDS_MCP)
        self.assertTrue(needs_mcp)

    def test_body_excludes_frontmatter(self):
        _, _, _, body = self._parse(SKILL_CONTENT_PLAIN)
        self.assertEqual(body, "Do the thing.\n")

    def test_no_frontmatter_returns_none_fields(self):
        effort, reasoning, needs_mcp, body = self._parse(SKILL_CONTENT_NO_FM)
        self.assertIsNone(effort)
        self.assertIsNone(reasoning)
        self.assertFalse(needs_mcp)
        self.assertEqual(body, SKILL_CONTENT_NO_FM)


# ---------------------------------------------------------------------------
# lookup_lmstudio_model
# ---------------------------------------------------------------------------

class TestLookupLmstudioModel(unittest.TestCase):

    def _lookup(self, effort, reasoning, tiers_content=TIERS_MD_WITH_LMSTUDIO):
        with patch("pathlib.Path.read_text", return_value=tiers_content):
            return skill_router.lookup_lmstudio_model(effort, reasoning)

    def test_returns_model_for_lm_studio_alias(self):
        model = self._lookup("RAPID", "MECHANICAL")
        self.assertEqual(model, "qwen/qwen3-8b (MLX, 4-bit)")

    def test_returns_none_for_non_lm_studio_alias(self):
        model = self._lookup("THOROUGH", "ARCHITECTURAL")
        self.assertIsNone(model)

    def test_returns_none_for_missing_combination(self):
        model = self._lookup("FOCUSED", "TACTICAL")
        self.assertIsNone(model)

    def test_returns_none_when_file_missing(self):
        with patch("pathlib.Path.read_text", side_effect=FileNotFoundError):
            model = skill_router.lookup_lmstudio_model("RAPID", "MECHANICAL")
        self.assertIsNone(model)

    def test_returns_none_when_section_missing(self):
        model = self._lookup("RAPID", "MECHANICAL", tiers_content="no active mapping here")
        self.assertIsNone(model)


# ---------------------------------------------------------------------------
# model_loaded
# ---------------------------------------------------------------------------

class TestModelLoaded(unittest.TestCase):

    def _fake_response(self, model_ids):
        data = json.dumps({"data": [{"id": mid} for mid in model_ids]}).encode()
        mock_resp = MagicMock()
        mock_resp.__enter__ = lambda s: s
        mock_resp.__exit__ = MagicMock(return_value=False)
        mock_resp.read = MagicMock(return_value=data)
        # json.load reads from the file-like object; patch it to return parsed data
        mock_resp.__iter__ = MagicMock(return_value=iter([]))
        return mock_resp

    def _run(self, model_name, loaded_ids):
        payload = json.dumps({"data": [{"id": mid} for mid in loaded_ids]}).encode()
        mock_resp = MagicMock()
        mock_resp.__enter__ = lambda s: s
        mock_resp.__exit__ = MagicMock(return_value=False)
        with patch("urllib.request.urlopen") as mock_urlopen:
            with patch("json.load", return_value={"data": [{"id": mid} for mid in loaded_ids]}):
                mock_urlopen.return_value = mock_resp
                return skill_router.model_loaded(model_name)

    def test_exact_base_name_match(self):
        self.assertTrue(self._run("qwen/qwen3-8b (MLX, 4-bit)", ["qwen/qwen3-8b"]))

    def test_mlx_suffix_variant_matches(self):
        self.assertTrue(self._run("qwen/qwen3-8b (MLX, 4-bit)", ["qwen/qwen3-8b-mlx"]))

    def test_no_match_returns_false(self):
        self.assertFalse(self._run("qwen/qwen3-8b (MLX, 4-bit)", ["mistralai/devstral-small"]))

    def test_unreachable_lm_studio_returns_false(self):
        with patch("urllib.request.urlopen", side_effect=Exception("connection refused")):
            self.assertFalse(skill_router.model_loaded("qwen/qwen3-8b"))


# ---------------------------------------------------------------------------
# stream_completion
# ---------------------------------------------------------------------------

class TestStreamCompletion(unittest.TestCase):

    def _make_sse_lines(self, chunks, done=True):
        lines = []
        for text in chunks:
            payload = json.dumps({"choices": [{"delta": {"content": text}}]})
            lines.append(f"data: {payload}\n".encode())
        if done:
            lines.append(b"data: [DONE]\n")
        return lines

    def test_streams_content_to_stdout(self):
        lines = self._make_sse_lines(["Hello", ", ", "world"])
        mock_resp = MagicMock()
        mock_resp.__enter__ = lambda s: s
        mock_resp.__exit__ = MagicMock(return_value=False)
        mock_resp.__iter__ = MagicMock(return_value=iter(lines))
        with patch("urllib.request.urlopen", return_value=mock_resp):
            with patch("sys.stdout", new_callable=io.StringIO) as mock_out:
                result = skill_router.stream_completion("qwen/qwen3-8b", "prompt")
        self.assertTrue(result)
        self.assertIn("Hello", mock_out.getvalue())
        self.assertIn("world", mock_out.getvalue())

    def test_returns_false_on_network_error(self):
        with patch("urllib.request.urlopen", side_effect=Exception("timeout")):
            result = skill_router.stream_completion("qwen/qwen3-8b", "prompt")
        self.assertFalse(result)

    def test_tolerates_malformed_chunks(self):
        lines = [b"data: not-json\n", b"data: [DONE]\n"]
        mock_resp = MagicMock()
        mock_resp.__enter__ = lambda s: s
        mock_resp.__exit__ = MagicMock(return_value=False)
        mock_resp.__iter__ = MagicMock(return_value=iter(lines))
        with patch("urllib.request.urlopen", return_value=mock_resp):
            result = skill_router.stream_completion("qwen/qwen3-8b", "prompt")
        self.assertTrue(result)

    def test_skips_non_data_lines(self):
        lines = [b"event: ping\n", b"data: [DONE]\n"]
        mock_resp = MagicMock()
        mock_resp.__enter__ = lambda s: s
        mock_resp.__exit__ = MagicMock(return_value=False)
        mock_resp.__iter__ = MagicMock(return_value=iter(lines))
        with patch("urllib.request.urlopen", return_value=mock_resp):
            result = skill_router.stream_completion("qwen/qwen3-8b", "prompt")
        self.assertTrue(result)


# ---------------------------------------------------------------------------
# main() — exit code paths
# ---------------------------------------------------------------------------

class TestMain(unittest.TestCase):

    def _run(self, argv):
        with patch("sys.argv", argv):
            with self.assertRaises(SystemExit) as ctx:
                skill_router.main()
        return ctx.exception.code

    def test_no_args_exits_2(self):
        self.assertEqual(self._run(["skill_router.py"]), 2)

    @patch("pathlib.Path.exists", return_value=False)
    def test_missing_skill_file_exits_2(self, _):
        self.assertEqual(self._run(["skill_router.py", "no/such/SKILL.md"]), 2)

    @patch("skill_router.read_frontmatter", return_value=(None, None, False, "body"))
    @patch("pathlib.Path.exists", return_value=True)
    def test_unparseable_frontmatter_exits_2(self, *_):
        self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 2)

    @patch("skill_router.read_frontmatter", return_value=("RAPID", "MECHANICAL", True, "body"))
    @patch("pathlib.Path.exists", return_value=True)
    def test_needs_mcp_exits_2(self, *_):
        self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 2)

    @patch("skill_router.lookup_lmstudio_model", return_value=None)
    @patch("skill_router.read_frontmatter", return_value=("FOCUSED", "ARCHITECTURAL", False, "body"))
    @patch("pathlib.Path.exists", return_value=True)
    def test_no_lmstudio_mapping_exits_2(self, *_):
        self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 2)

    @patch("skill_router.model_loaded", return_value=False)
    @patch("skill_router.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch("skill_router.read_frontmatter", return_value=("RAPID", "MECHANICAL", False, "body"))
    @patch("pathlib.Path.exists", return_value=True)
    def test_model_not_loaded_exits_1(self, *_):
        self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 1)

    @patch("skill_router.stream_completion", return_value=False)
    @patch("skill_router.model_loaded", return_value=True)
    @patch("skill_router.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch("skill_router.read_frontmatter", return_value=("RAPID", "MECHANICAL", False, "body"))
    @patch("pathlib.Path.exists", return_value=True)
    def test_stream_failure_exits_1(self, *_):
        self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 1)

    @patch("skill_router.stream_completion", return_value=True)
    @patch("skill_router.model_loaded", return_value=True)
    @patch("skill_router.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch("skill_router.read_frontmatter", return_value=("RAPID", "MECHANICAL", False, "body"))
    @patch("pathlib.Path.exists", return_value=True)
    def test_success_does_not_exit(self, *_):
        with patch("sys.argv", ["skill_router.py", "fake/SKILL.md"]):
            skill_router.main()  # must not raise

    @patch("skill_router.stream_completion")
    @patch("skill_router.model_loaded", return_value=True)
    @patch("skill_router.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch("skill_router.read_frontmatter", return_value=("RAPID", "MECHANICAL", False, "body"))
    @patch("pathlib.Path.exists", return_value=True)
    def test_extra_args_appended_to_prompt(self, _exists, _fm, _model, _loaded, mock_stream):
        mock_stream.return_value = True
        with patch("sys.argv", ["skill_router.py", "fake/SKILL.md", "--args", "PR #42"]):
            skill_router.main()
        call_prompt = mock_stream.call_args[0][1]
        self.assertIn("PR #42", call_prompt)
        self.assertIn("body", call_prompt)

    @patch("skill_router.stream_completion")
    @patch("skill_router.model_loaded", return_value=True)
    @patch("skill_router.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch("skill_router.read_frontmatter", return_value=("RAPID", "MECHANICAL", False, "body"))
    @patch("pathlib.Path.exists", return_value=True)
    def test_api_model_name_is_normalized(self, _exists, _fm, _model, _loaded, mock_stream):
        mock_stream.return_value = True
        with patch("sys.argv", ["skill_router.py", "fake/SKILL.md"]):
            skill_router.main()
        api_model = mock_stream.call_args[0][0]
        self.assertNotIn("(", api_model)
        self.assertEqual(api_model, "qwen/qwen3-8b")


if __name__ == "__main__":
    unittest.main()
