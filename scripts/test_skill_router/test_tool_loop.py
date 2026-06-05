import io
import json
import unittest
from unittest.mock import MagicMock, patch

from skill_router.tool_loop import _build_tools, _execute_tool, chat_completion_with_tools


def _make_completion_response(content=None, tool_calls=None, finish_reason=None):
    msg = {"role": "assistant"}
    if content is not None:
        msg["content"] = content
    if tool_calls is not None:
        msg["tool_calls"] = tool_calls
    if finish_reason is None:
        finish_reason = "tool_calls" if tool_calls else "stop"
    return {"choices": [{"message": msg, "finish_reason": finish_reason}]}


class TestBuildTools(unittest.TestCase):

    def test_empty_groups_returns_empty_list(self):
        self.assertEqual(_build_tools([]), [])

    def test_linear_group_returns_linear_tools(self):
        tools = _build_tools(["linear"])
        names = [t["function"]["name"] for t in tools]
        self.assertIn("linear_list_issues", names)
        self.assertIn("linear_get_issue", names)
        self.assertIn("linear_update_issue_state", names)
        self.assertIn("linear_create_comment", names)

    def test_github_group_returns_github_tools(self):
        tools = _build_tools(["github"])
        names = [t["function"]["name"] for t in tools]
        self.assertIn("github_get_pr", names)
        self.assertIn("github_get_pr_diff", names)
        self.assertIn("github_create_pr_comment", names)
        self.assertIn("github_merge_pr", names)

    def test_files_group_returns_files_tools(self):
        tools = _build_tools(["files"])
        names = [t["function"]["name"] for t in tools]
        self.assertIn("read_file", names)
        self.assertIn("write_file", names)
        self.assertIn("run_bash", names)

    def test_multiple_groups_combined(self):
        tools = _build_tools(["linear", "github"])
        names = [t["function"]["name"] for t in tools]
        self.assertIn("linear_get_issue", names)
        self.assertIn("github_get_pr", names)
        self.assertNotIn("read_file", names)

    def test_unknown_group_logs_warning(self):
        with patch("sys.stderr") as mock_err:
            tools = _build_tools(["unknown_group"])
        self.assertEqual(tools, [])
        written = "".join(c.args[0] for c in mock_err.write.call_args_list)
        self.assertIn("Unknown tool group 'unknown_group'", written)


class TestExecuteTool(unittest.TestCase):

    def test_linear_tool_dispatches_to_linear_executor(self):
        with patch("skill_router.tool_loop._execute_linear_tool", return_value="ok") as mock_exec:
            result = _execute_tool("linear_get_issue", {"identifier": "HAB-1"}, linear_api_key="key")
        mock_exec.assert_called_once_with("linear_get_issue", {"identifier": "HAB-1"}, "key")
        self.assertEqual(result, "ok")

    def test_github_tool_dispatches_to_github_executor(self):
        with patch("skill_router.tool_loop._execute_github_tool", return_value="ok") as mock_exec:
            result = _execute_tool("github_get_pr", {"number": 42})
        mock_exec.assert_called_once_with("github_get_pr", {"number": 42})
        self.assertEqual(result, "ok")

    def test_files_tool_dispatches_to_files_executor(self):
        with patch("skill_router.tool_loop._execute_files_tool", return_value="content") as mock_exec:
            result = _execute_tool("read_file", {"path": "foo.txt"})
        mock_exec.assert_called_once_with("read_file", {"path": "foo.txt"})
        self.assertEqual(result, "content")

    def test_linear_tool_without_api_key_returns_error(self):
        result = _execute_tool("linear_get_issue", {"identifier": "HAB-1"})
        self.assertIn("LINEAR_API_KEY", result)

    def test_unknown_tool_returns_error_string(self):
        result = _execute_tool("unknown_tool", {})
        self.assertIn("unknown tool", result)


class TestChatCompletionWithTools(unittest.TestCase):

    def test_final_answer_printed_and_returns_true(self):
        response = _make_completion_response(content="All done.")
        with patch("urllib.request.urlopen") as mock_open:
            with patch("json.load", return_value=response):
                mock_resp = MagicMock()
                mock_resp.__enter__ = lambda s: s
                mock_resp.__exit__ = MagicMock(return_value=False)
                mock_open.return_value = mock_resp
                with patch("sys.stdout", new_callable=io.StringIO) as out:
                    result = chat_completion_with_tools("model", "prompt", [])
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
                with patch("skill_router.tool_loop._execute_tool", return_value="file content") as mock_exec:
                    with patch("sys.stdout", new_callable=io.StringIO):
                        result = chat_completion_with_tools("model", "prompt", [])
        self.assertTrue(result)
        mock_exec.assert_called_once_with("read_file", {"path": "foo.txt"}, linear_api_key=None)

    def test_network_error_returns_false(self):
        with patch("urllib.request.urlopen", side_effect=Exception("connection refused")):
            result = chat_completion_with_tools("model", "prompt", [])
        self.assertFalse(result)

    def test_empty_choices_returns_false(self):
        mock_resp = MagicMock()
        mock_resp.__enter__ = lambda s: s
        mock_resp.__exit__ = MagicMock(return_value=False)
        with patch("urllib.request.urlopen", return_value=mock_resp):
            with patch("json.load", return_value={"choices": []}):
                result = chat_completion_with_tools("model", "prompt", [])
        self.assertFalse(result)

    def test_max_turns_exceeded_returns_false(self):
        tool_call_resp = _make_completion_response(
            tool_calls=[{
                "id": "tc1",
                "function": {"name": "read_file", "arguments": '{"path": "x"}'},
            }],
        )
        mock_resp = MagicMock()
        mock_resp.__enter__ = lambda s: s
        mock_resp.__exit__ = MagicMock(return_value=False)
        with patch("urllib.request.urlopen", return_value=mock_resp):
            with patch("json.load", return_value=tool_call_resp):
                with patch("skill_router.tool_loop._execute_tool", return_value="result"):
                    result = chat_completion_with_tools("model", "prompt", [])
        self.assertFalse(result)


if __name__ == "__main__":
    unittest.main()
