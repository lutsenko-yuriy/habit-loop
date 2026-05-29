#!/usr/bin/env python3
"""Unit tests for skill_router.py — run with: python3 scripts/test_skill_router.py"""

import io
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, call, patch

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
SKILL_CONTENT_NEEDS_MCP = "---\neffort: RAPID\nreasoning: MECHANICAL\nneeds_session_tools: true\n---\nDo the thing.\n"
SKILL_CONTENT_WITH_CONTEXT = "---\neffort: RAPID\nreasoning: MECHANICAL\ncontext: linear\n---\nDo the thing.\n"
SKILL_CONTENT_WITH_TOOLS = "---\neffort: RAPID\nreasoning: MECHANICAL\ntools: linear,github\n---\nDo the thing.\n"
SKILL_CONTENT_NO_FM = "No frontmatter here."

# Shorthand 6-tuples for read_frontmatter mocks
_FM_PLAIN = ("RAPID", "MECHANICAL", False, None, [], "body")
_FM_SESSION_TOOLS = ("RAPID", "MECHANICAL", True, None, [], "body")
_FM_NO_EFFORT = (None, None, False, None, [], "body")
_FM_FOCUSED = ("FOCUSED", "ARCHITECTURAL", False, None, [], "body")
_FM_WITH_CONTEXT = ("RAPID", "MECHANICAL", False, "linear", [], "body")
_FM_WITH_TOOLS_LINEAR = ("RAPID", "MECHANICAL", False, None, ["linear"], "body")
_FM_WITH_TOOLS_GITHUB = ("RAPID", "MECHANICAL", False, None, ["github", "files"], "body")


# ---------------------------------------------------------------------------
# _auth_headers
# ---------------------------------------------------------------------------

class TestAuthHeaders(unittest.TestCase):

    def test_returns_empty_dict_when_no_token(self):
        with patch.dict("os.environ", {}, clear=True):
            self.assertEqual(skill_router._auth_headers(), {})

    def test_returns_bearer_header_when_token_set(self):
        with patch.dict("os.environ", {"LM_API_TOKEN": "sk-lm-test123"}):
            self.assertEqual(
                skill_router._auth_headers(),
                {"Authorization": "Bearer sk-lm-test123"},
            )


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
        effort, reasoning, _, _, _, _ = self._parse(SKILL_CONTENT_PLAIN)
        self.assertEqual(effort, "RAPID")
        self.assertEqual(reasoning, "MECHANICAL")

    def test_needs_session_tools_false_by_default(self):
        _, _, needs_session_tools, _, _, _ = self._parse(SKILL_CONTENT_PLAIN)
        self.assertFalse(needs_session_tools)

    def test_needs_session_tools_true_when_set(self):
        _, _, needs_session_tools, _, _, _ = self._parse(SKILL_CONTENT_NEEDS_MCP)
        self.assertTrue(needs_session_tools)

    def test_context_none_by_default(self):
        _, _, _, context, _, _ = self._parse(SKILL_CONTENT_PLAIN)
        self.assertIsNone(context)

    def test_context_parsed_when_set(self):
        _, _, _, context, _, _ = self._parse(SKILL_CONTENT_WITH_CONTEXT)
        self.assertEqual(context, "linear")

    def test_tools_empty_by_default(self):
        _, _, _, _, tools, _ = self._parse(SKILL_CONTENT_PLAIN)
        self.assertEqual(tools, [])

    def test_tools_parsed_when_set(self):
        _, _, _, _, tools, _ = self._parse(SKILL_CONTENT_WITH_TOOLS)
        self.assertEqual(tools, ["linear", "github"])

    def test_body_excludes_frontmatter(self):
        _, _, _, _, _, body = self._parse(SKILL_CONTENT_PLAIN)
        self.assertEqual(body, "Do the thing.\n")

    def test_no_frontmatter_returns_none_fields(self):
        effort, reasoning, needs_session_tools, context, tools, body = self._parse(SKILL_CONTENT_NO_FM)
        self.assertIsNone(effort)
        self.assertIsNone(reasoning)
        self.assertFalse(needs_session_tools)
        self.assertIsNone(context)
        self.assertEqual(tools, [])
        self.assertEqual(body, SKILL_CONTENT_NO_FM)


# ---------------------------------------------------------------------------
# _build_tools
# ---------------------------------------------------------------------------

class TestBuildTools(unittest.TestCase):

    def test_empty_groups_returns_empty_list(self):
        self.assertEqual(skill_router._build_tools([]), [])

    def test_linear_group_returns_linear_tools(self):
        tools = skill_router._build_tools(["linear"])
        names = [t["function"]["name"] for t in tools]
        self.assertIn("linear_list_issues", names)
        self.assertIn("linear_get_issue", names)
        self.assertIn("linear_update_issue_state", names)
        self.assertIn("linear_create_comment", names)

    def test_github_group_returns_github_tools(self):
        tools = skill_router._build_tools(["github"])
        names = [t["function"]["name"] for t in tools]
        self.assertIn("github_get_pr", names)
        self.assertIn("github_get_pr_diff", names)
        self.assertIn("github_create_pr_comment", names)
        self.assertIn("github_merge_pr", names)

    def test_files_group_returns_files_tools(self):
        tools = skill_router._build_tools(["files"])
        names = [t["function"]["name"] for t in tools]
        self.assertIn("read_file", names)
        self.assertIn("write_file", names)
        self.assertIn("run_bash", names)

    def test_multiple_groups_combined(self):
        tools = skill_router._build_tools(["linear", "github"])
        names = [t["function"]["name"] for t in tools]
        self.assertIn("linear_get_issue", names)
        self.assertIn("github_get_pr", names)
        self.assertNotIn("read_file", names)

    def test_unknown_group_ignored(self):
        tools = skill_router._build_tools(["unknown_group"])
        self.assertEqual(tools, [])


# ---------------------------------------------------------------------------
# _execute_tool dispatcher
# ---------------------------------------------------------------------------

class TestExecuteTool(unittest.TestCase):

    def test_linear_tool_dispatches_to_linear_executor(self):
        with patch("skill_router._execute_linear_tool", return_value="ok") as mock_exec:
            result = skill_router._execute_tool("linear_get_issue", {"identifier": "HAB-1"}, linear_api_key="key")
        mock_exec.assert_called_once_with("linear_get_issue", {"identifier": "HAB-1"}, "key")
        self.assertEqual(result, "ok")

    def test_github_tool_dispatches_to_github_executor(self):
        with patch("skill_router._execute_github_tool", return_value="ok") as mock_exec:
            result = skill_router._execute_tool("github_get_pr", {"number": 42})
        mock_exec.assert_called_once_with("github_get_pr", {"number": 42})
        self.assertEqual(result, "ok")

    def test_files_tool_dispatches_to_files_executor(self):
        with patch("skill_router._execute_files_tool", return_value="content") as mock_exec:
            result = skill_router._execute_tool("read_file", {"path": "foo.txt"})
        mock_exec.assert_called_once_with("read_file", {"path": "foo.txt"})
        self.assertEqual(result, "content")

    def test_linear_tool_without_api_key_returns_error(self):
        result = skill_router._execute_tool("linear_get_issue", {"identifier": "HAB-1"})
        self.assertIn("LINEAR_API_KEY", result)

    def test_unknown_tool_returns_error_string(self):
        result = skill_router._execute_tool("unknown_tool", {})
        self.assertIn("unknown tool", result)


# ---------------------------------------------------------------------------
# chat_completion_with_tools
# ---------------------------------------------------------------------------

def _make_completion_response(content=None, tool_calls=None, finish_reason=None):
    """Build a fake non-streaming /chat/completions response dict."""
    msg = {"role": "assistant"}
    if content is not None:
        msg["content"] = content
    if tool_calls is not None:
        msg["tool_calls"] = tool_calls
    if finish_reason is None:
        finish_reason = "tool_calls" if tool_calls else "stop"
    return {"choices": [{"message": msg, "finish_reason": finish_reason}]}


class TestChatCompletionWithTools(unittest.TestCase):

    def _urlopen_returning(self, responses):
        """Return a urlopen mock that yields successive response dicts."""
        call_count = [0]
        def fake_urlopen(req, timeout=None):
            resp_data = json.dumps(responses[call_count[0]]).encode()
            call_count[0] += 1
            mock_resp = MagicMock()
            mock_resp.__enter__ = lambda s: s
            mock_resp.__exit__ = MagicMock(return_value=False)
            mock_resp.read = MagicMock(return_value=resp_data)
            with patch("json.load", return_value=json.loads(resp_data)):
                pass
            # patch json.load at call site
            return mock_resp
        return fake_urlopen

    def test_final_answer_printed_and_returns_true(self):
        response = _make_completion_response(content="All done.")
        with patch("urllib.request.urlopen") as mock_open:
            with patch("json.load", return_value=response):
                mock_resp = MagicMock()
                mock_resp.__enter__ = lambda s: s
                mock_resp.__exit__ = MagicMock(return_value=False)
                mock_open.return_value = mock_resp
                with patch("sys.stdout", new_callable=io.StringIO) as out:
                    result = skill_router.chat_completion_with_tools("model", "prompt", [])
        self.assertTrue(result)
        self.assertIn("All done.", out.getvalue())

    def test_tool_call_dispatched_then_final_answer(self):
        tool_call_resp = _make_completion_response(
            tool_calls=[{
                "id": "tc1",
                "function": {"name": "read_file", "arguments": '{"path": "foo.txt"}'},
            }],
        )
        final_resp = _make_completion_response(content="Done after tool.")

        responses = [tool_call_resp, final_resp]
        call_idx = [0]

        def fake_urlopen(req, timeout=None):
            resp = responses[call_idx[0]]
            call_idx[0] += 1
            mock_resp = MagicMock()
            mock_resp.__enter__ = lambda s: s
            mock_resp.__exit__ = MagicMock(return_value=False)
            with patch("json.load", return_value=resp):
                pass
            return mock_resp

        with patch("urllib.request.urlopen", side_effect=fake_urlopen):
            with patch("json.load", side_effect=[tool_call_resp, final_resp]):
                with patch("skill_router._execute_tool", return_value="file content") as mock_exec:
                    with patch("sys.stdout", new_callable=io.StringIO) as out:
                        result = skill_router.chat_completion_with_tools("model", "prompt", [])
        self.assertTrue(result)
        mock_exec.assert_called_once_with("read_file", {"path": "foo.txt"}, linear_api_key=None)

    def test_network_error_returns_false(self):
        with patch("urllib.request.urlopen", side_effect=Exception("connection refused")):
            result = skill_router.chat_completion_with_tools("model", "prompt", [])
        self.assertFalse(result)

    def test_empty_choices_returns_false(self):
        with patch("urllib.request.urlopen"):
            with patch("json.load", return_value={"choices": []}):
                mock_resp = MagicMock()
                mock_resp.__enter__ = lambda s: s
                mock_resp.__exit__ = MagicMock(return_value=False)
                with patch("urllib.request.urlopen", return_value=mock_resp):
                    result = skill_router.chat_completion_with_tools("model", "prompt", [])
        self.assertFalse(result)

    def test_max_turns_exceeded_returns_false(self):
        # Every response is a tool call — loop should hit MAX_TOOL_TURNS
        tool_call_resp = _make_completion_response(
            tool_calls=[{
                "id": "tc1",
                "function": {"name": "read_file", "arguments": '{"path": "x"}'},
            }],
        )
        with patch("urllib.request.urlopen"):
            with patch("json.load", return_value=tool_call_resp):
                with patch("skill_router._execute_tool", return_value="result"):
                    mock_resp = MagicMock()
                    mock_resp.__enter__ = lambda s: s
                    mock_resp.__exit__ = MagicMock(return_value=False)
                    with patch("urllib.request.urlopen", return_value=mock_resp):
                        result = skill_router.chat_completion_with_tools("model", "prompt", [])
        self.assertFalse(result)


# ---------------------------------------------------------------------------
# fetch_linear_context / format_linear_context
# ---------------------------------------------------------------------------

FAKE_LINEAR_DATA = {
    "issues": [
        {"identifier": "HAB-10", "title": "Fix crash", "description": "App crashes on launch", "state": {"name": "Backlog", "type": "backlog"}, "labels": {"nodes": [{"name": "Bug"}]}},
        {"identifier": "HAB-11", "title": "Add feature", "description": "New user-facing capability", "state": {"name": "Backlog", "type": "backlog"}, "labels": {"nodes": [{"name": "Feature"}]}},
        {"identifier": "HAB-12", "title": "Unlabeled issue", "description": None, "state": {"name": "Backlog", "type": "backlog"}, "labels": {"nodes": []}},
    ],
    "milestones": [
        {"name": "v1.0.0", "progress": 75, "targetDate": "2026-06-01", "status": "inProgress"},
    ],
}


class TestFetchLinearContext(unittest.TestCase):

    def _mock_graphql(self, issues_nodes, milestone_nodes):
        def fake_graphql(api_key, query, variables=None):
            if "issues" in query:
                return {"data": {"issues": {"nodes": issues_nodes}}}
            return {"data": {"project": {"projectMilestones": {"nodes": milestone_nodes}}}}
        return fake_graphql

    def test_returns_issues_and_milestones(self):
        with patch("skill_router._linear_graphql", side_effect=self._mock_graphql(
            [{"identifier": "HAB-1", "title": "T", "state": {"name": "Backlog", "type": "backlog"}, "labels": {"nodes": []}}],
            [{"name": "v1.0.0", "progress": 50, "targetDate": "2026-06-01", "status": "inProgress"}],
        )):
            result = skill_router.fetch_linear_context("key")
        self.assertEqual(len(result["issues"]), 1)
        self.assertEqual(len(result["milestones"]), 1)

    def test_returns_empty_lists_on_missing_data(self):
        with patch("skill_router._linear_graphql", return_value={"data": {}}):
            result = skill_router.fetch_linear_context("key")
        self.assertEqual(result["issues"], [])
        self.assertEqual(result["milestones"], [])

    def test_propagates_exception_on_network_error(self):
        with patch("skill_router._linear_graphql", side_effect=Exception("timeout")):
            with self.assertRaises(Exception):
                skill_router.fetch_linear_context("key")


class TestFormatLinearContext(unittest.TestCase):

    def test_active_milestone_shown(self):
        result = skill_router.format_linear_context(FAKE_LINEAR_DATA)
        self.assertIn("v1.0.0", result)
        self.assertIn("75%", result)

    def test_no_active_milestone_when_all_done(self):
        data = {**FAKE_LINEAR_DATA, "milestones": [{"name": "v1.0.0", "progress": 100, "status": "done", "targetDate": "2026-01-01"}]}
        result = skill_router.format_linear_context(data)
        self.assertIn("Active milestone: none", result)

    def test_issues_grouped_by_label(self):
        result = skill_router.format_linear_context(FAKE_LINEAR_DATA)
        self.assertIn("HAB-10", result)
        self.assertIn("HAB-11", result)
        self.assertIn("HAB-12", result)

    def test_description_included_in_issue_line(self):
        result = skill_router.format_linear_context(FAKE_LINEAR_DATA)
        self.assertIn("App crashes on launch", result)
        self.assertIn("New user-facing capability", result)

    def test_none_description_omitted(self):
        result = skill_router.format_linear_context(FAKE_LINEAR_DATA)
        for line in result.splitlines():
            if "HAB-12" in line:
                self.assertNotIn("None", line)

    def test_no_milestone_shows_none_without_percentage(self):
        data = {**FAKE_LINEAR_DATA, "milestones": []}
        result = skill_router.format_linear_context(data)
        self.assertIn("Active milestone: none", result)
        self.assertNotIn("%", result.split("Active milestone:")[1].split("\n")[0])

    def test_no_recently_completed_placeholder(self):
        result = skill_router.format_linear_context(FAKE_LINEAR_DATA)
        self.assertNotIn("Recently completed", result)

    def test_output_has_context_markers(self):
        result = skill_router.format_linear_context(FAKE_LINEAR_DATA)
        self.assertIn("=== PRE-FETCHED BACKLOG", result)
        self.assertIn("=== END PRE-FETCHED BACKLOG ===", result)


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

    def _run(self, model_name, loaded_ids):
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

    @patch("skill_router.read_frontmatter", return_value=_FM_NO_EFFORT)
    @patch("pathlib.Path.exists", return_value=True)
    def test_unparseable_frontmatter_exits_2(self, *_):
        self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 2)

    @patch("skill_router.read_frontmatter", return_value=_FM_SESSION_TOOLS)
    @patch("pathlib.Path.exists", return_value=True)
    def test_needs_session_tools_exits_2(self, *_):
        self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 2)

    @patch("skill_router.lookup_lmstudio_model", return_value=None)
    @patch("skill_router.read_frontmatter", return_value=_FM_FOCUSED)
    @patch("pathlib.Path.exists", return_value=True)
    def test_no_lmstudio_mapping_exits_2(self, *_):
        self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 2)

    @patch("skill_router.model_loaded", return_value=False)
    @patch("skill_router.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch("skill_router.read_frontmatter", return_value=_FM_PLAIN)
    @patch("pathlib.Path.exists", return_value=True)
    def test_model_not_loaded_exits_1(self, *_):
        self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 1)

    @patch("skill_router.stream_completion", return_value=False)
    @patch("skill_router.model_loaded", return_value=True)
    @patch("skill_router.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch("skill_router.read_frontmatter", return_value=_FM_PLAIN)
    @patch("pathlib.Path.exists", return_value=True)
    def test_stream_failure_exits_1(self, *_):
        self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 1)

    @patch("skill_router.stream_completion", return_value=True)
    @patch("skill_router.model_loaded", return_value=True)
    @patch("skill_router.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch("skill_router.read_frontmatter", return_value=_FM_PLAIN)
    @patch("pathlib.Path.exists", return_value=True)
    def test_success_does_not_exit(self, *_):
        with patch("sys.argv", ["skill_router.py", "fake/SKILL.md"]):
            skill_router.main()  # must not raise

    @patch("skill_router.stream_completion")
    @patch("skill_router.model_loaded", return_value=True)
    @patch("skill_router.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch("skill_router.read_frontmatter", return_value=_FM_PLAIN)
    @patch("pathlib.Path.exists", return_value=True)
    def test_extra_args_appended_to_prompt(self, _exists, _fm, _model, _loaded, mock_stream):
        mock_stream.return_value = True
        with patch("sys.argv", ["skill_router.py", "fake/SKILL.md", "--args", "PR #42"]):
            skill_router.main()
        call_prompt = mock_stream.call_args[0][1]
        self.assertIn("PR #42", call_prompt)
        self.assertIn("body", call_prompt)

    # -- context: linear --

    @patch("skill_router.stream_completion", return_value=True)
    @patch("skill_router.model_loaded", return_value=True)
    @patch("skill_router.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch("skill_router.fetch_linear_context", return_value={"issues": [], "milestones": []})
    @patch("skill_router.read_frontmatter", return_value=_FM_WITH_CONTEXT)
    @patch("pathlib.Path.exists", return_value=True)
    def test_context_linear_fetches_and_prepends(self, _exists, _fm, mock_fetch, _model, _loaded, mock_stream):
        with patch.dict("os.environ", {"LINEAR_API_KEY": "lin_api_test"}):
            with patch("sys.argv", ["skill_router.py", "fake/SKILL.md"]):
                skill_router.main()
        mock_fetch.assert_called_once_with("lin_api_test")
        prompt = mock_stream.call_args[0][1]
        self.assertIn("PRE-FETCHED BACKLOG", prompt)
        self.assertIn("body", prompt)

    @patch("skill_router.read_frontmatter", return_value=_FM_WITH_CONTEXT)
    @patch("pathlib.Path.exists", return_value=True)
    def test_context_linear_exits_2_without_api_key(self, *_):
        with patch.dict("os.environ", {}, clear=True):
            self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 2)

    @patch("skill_router.fetch_linear_context", side_effect=Exception("network error"))
    @patch("skill_router.read_frontmatter", return_value=_FM_WITH_CONTEXT)
    @patch("pathlib.Path.exists", return_value=True)
    def test_context_linear_exits_1_on_fetch_error(self, *_):
        with patch.dict("os.environ", {"LINEAR_API_KEY": "lin_api_test"}):
            self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 1)

    # -- tools: ... --

    @patch("skill_router.chat_completion_with_tools", return_value=True)
    @patch("skill_router.model_loaded", return_value=True)
    @patch("skill_router.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch("skill_router.read_frontmatter", return_value=_FM_WITH_TOOLS_GITHUB)
    @patch("pathlib.Path.exists", return_value=True)
    def test_tools_dispatches_to_chat_completion(self, _exists, _fm, _model, _loaded, mock_chat):
        with patch("sys.argv", ["skill_router.py", "fake/SKILL.md"]):
            skill_router.main()
        mock_chat.assert_called_once()
        _, _, tools = mock_chat.call_args[0]
        tool_names = [t["function"]["name"] for t in tools]
        self.assertIn("github_get_pr", tool_names)
        self.assertIn("read_file", tool_names)

    @patch("skill_router.read_frontmatter", return_value=_FM_WITH_TOOLS_LINEAR)
    @patch("pathlib.Path.exists", return_value=True)
    def test_tools_linear_exits_2_without_api_key(self, *_):
        with patch.dict("os.environ", {}, clear=True):
            self.assertEqual(self._run(["skill_router.py", "fake/SKILL.md"]), 2)

    @patch("skill_router.stream_completion", return_value=True)
    @patch("skill_router.model_loaded", return_value=True)
    @patch("skill_router.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch("skill_router.read_frontmatter", return_value=_FM_PLAIN)
    @patch("pathlib.Path.exists", return_value=True)
    def test_no_tools_uses_stream_completion(self, _exists, _fm, _model, _loaded, mock_stream):
        mock_stream.return_value = True
        with patch("sys.argv", ["skill_router.py", "fake/SKILL.md"]):
            skill_router.main()
        mock_stream.assert_called_once()

    @patch("skill_router.stream_completion")
    @patch("skill_router.model_loaded", return_value=True)
    @patch("skill_router.lookup_lmstudio_model", return_value="qwen/qwen3-8b (MLX, 4-bit)")
    @patch("skill_router.read_frontmatter", return_value=_FM_PLAIN)
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
