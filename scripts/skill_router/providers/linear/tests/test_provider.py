import json
import unittest
from pathlib import Path
from unittest.mock import patch

from skill_router.providers.linear.context import format_linear_context
from skill_router.providers.linear.provider import LinearProvider


_SAMPLE_DATA = {
    "issues": [
        {
            "identifier": "HAB-1",
            "title": "T",
            "description": "d",
            "url": "https://linear.app/x/issue/HAB-1",
            "state": {"name": "Todo", "type": "unstarted"},
            "labels": {"nodes": []},
        }
    ],
    "milestones": [],
}


class TestLinearProvider(unittest.TestCase):

    def test_validate_returns_none_when_api_key_set(self):
        p = LinearProvider(api_key="lin_api_test", project_id="proj")
        self.assertIsNone(p.validate())

    def test_validate_returns_error_when_no_api_key(self):
        p = LinearProvider(api_key=None, project_id="proj")
        err = p.validate()
        self.assertIsNotNone(err)
        self.assertIn("LINEAR_API_KEY", err)

    def test_handles_linear_tool_names(self):
        p = LinearProvider(api_key="x", project_id="y")
        self.assertTrue(p.handles("linear_list_issues"))
        self.assertTrue(p.handles("linear_get_issue"))
        self.assertTrue(p.handles("linear_update_issue_state"))
        self.assertTrue(p.handles("linear_create_comment"))
        self.assertFalse(p.handles("github_get_pr"))
        self.assertFalse(p.handles("read_file"))

    def test_dispatch_linear_list_issues(self):
        fake_nodes = [{"identifier": "HAB-1", "title": "T"}]
        with patch(
            "skill_router.providers.linear.provider._linear_graphql",
            return_value={"data": {"issues": {"nodes": fake_nodes}}},
        ) as mock_gql:
            p = LinearProvider(api_key="key", project_id="proj")
            result = p.dispatch("linear_list_issues", {})
        self.assertEqual(json.loads(result), fake_nodes)
        mock_gql.assert_called_once()

    def test_format_context_is_pure_markdown_no_side_effects(self):
        # HAB-222: format_context must never trigger the HTML side effect — only
        # render_backlog_view does, and only for skills that opt in.
        p = LinearProvider(api_key="key", project_id="proj")
        with patch("skill_router.providers.linear.provider.write_backlog_html") as mock_write, patch(
            "skill_router.providers.linear.provider.open_in_browser"
        ) as mock_open:
            text = p.format_context(_SAMPLE_DATA)

        mock_write.assert_not_called()
        mock_open.assert_not_called()
        self.assertEqual(text, format_linear_context(_SAMPLE_DATA))

    def test_render_backlog_view_writes_html_and_returns_file_note(self):
        p = LinearProvider(api_key="key", project_id="proj")
        written_path = Path("/tmp/backlog.local.html")
        with patch(
            "skill_router.providers.linear.provider.write_backlog_html",
            return_value=written_path,
        ) as mock_write, patch(
            "skill_router.providers.linear.provider.open_in_browser", return_value=True
        ) as mock_open:
            note = p.render_backlog_view(_SAMPLE_DATA)

        mock_write.assert_called_once()
        write_args = mock_write.call_args[0]
        self.assertEqual(write_args[1], Path("backlog.local.html"))
        # resolve() may remap the mocked path (e.g. /tmp -> /private/tmp on macOS)
        resolved = written_path.resolve()
        mock_open.assert_called_once_with(resolved)
        self.assertIn(str(resolved), note)

    def test_render_backlog_view_honours_path_override_env_var(self):
        p = LinearProvider(api_key="key", project_id="proj")
        with patch.dict("os.environ", {"HL_BACKLOG_HTML_PATH": "/tmp/custom.html"}):
            with patch(
                "skill_router.providers.linear.provider.write_backlog_html",
                return_value=Path("/tmp/custom.html"),
            ) as mock_write, patch("skill_router.providers.linear.provider.open_in_browser", return_value=True):
                p.render_backlog_view(_SAMPLE_DATA)

        write_args = mock_write.call_args[0]
        self.assertEqual(write_args[1], Path("/tmp/custom.html"))

    def test_render_backlog_view_returns_empty_string_on_write_failure(self):
        p = LinearProvider(api_key="key", project_id="proj")
        with patch(
            "skill_router.providers.linear.provider.render_backlog_html",
            side_effect=RuntimeError("boom"),
        ):
            note = p.render_backlog_view(_SAMPLE_DATA)

        self.assertEqual(note, "")

    def test_render_backlog_view_keeps_file_note_when_only_open_fails(self):
        # HAB-222 audit finding: a browser-open failure must not drop the note
        # for a file that was actually written successfully.
        p = LinearProvider(api_key="key", project_id="proj")
        written_path = Path("/tmp/backlog.local.html")
        with patch(
            "skill_router.providers.linear.provider.write_backlog_html",
            return_value=written_path,
        ), patch(
            "skill_router.providers.linear.provider.open_in_browser",
            side_effect=RuntimeError("no browser available"),
        ):
            note = p.render_backlog_view(_SAMPLE_DATA)

        self.assertIn(str(written_path.resolve()), note)

    def test_render_backlog_view_never_raises(self):
        p = LinearProvider(api_key="key", project_id="proj")
        with patch(
            "skill_router.providers.linear.provider.render_backlog_html",
            side_effect=RuntimeError("boom"),
        ):
            try:
                p.render_backlog_view(_SAMPLE_DATA)
            except Exception as e:
                self.fail(f"render_backlog_view raised {e!r} — it must never raise")


if __name__ == "__main__":
    unittest.main()
