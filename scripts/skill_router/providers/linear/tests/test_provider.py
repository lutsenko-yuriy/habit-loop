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

    def test_format_context_writes_html_and_appends_file_note(self):
        p = LinearProvider(api_key="key", project_id="proj")
        with patch(
            "skill_router.providers.linear.provider.write_backlog_html",
            return_value=Path("/tmp/backlog.local.html"),
        ) as mock_write, patch(
            "skill_router.providers.linear.provider.open_in_browser", return_value=True
        ) as mock_open:
            text = p.format_context(_SAMPLE_DATA)

        mock_write.assert_called_once()
        mock_open.assert_called_once_with(Path("/tmp/backlog.local.html"))
        self.assertIn("=== PRE-FETCHED BACKLOG", text)
        self.assertIn("=== END PRE-FETCHED BACKLOG ===", text)
        self.assertIn("/tmp/backlog.local.html", text)

    def test_format_context_degrades_gracefully_on_html_failure(self):
        p = LinearProvider(api_key="key", project_id="proj")
        with patch(
            "skill_router.providers.linear.provider.render_backlog_html",
            side_effect=RuntimeError("boom"),
        ):
            text = p.format_context(_SAMPLE_DATA)

        self.assertIn("=== PRE-FETCHED BACKLOG", text)
        self.assertIn("=== END PRE-FETCHED BACKLOG ===", text)
        self.assertNotIn("Backlog table:", text)

    def test_format_context_markdown_block_unchanged_regardless_of_html_outcome(self):
        expected_markdown = format_linear_context(_SAMPLE_DATA)
        p = LinearProvider(api_key="key", project_id="proj")

        with patch(
            "skill_router.providers.linear.provider.write_backlog_html",
            return_value=Path("/tmp/backlog.local.html"),
        ), patch("skill_router.providers.linear.provider.open_in_browser", return_value=True):
            success_text = p.format_context(_SAMPLE_DATA)

        with patch(
            "skill_router.providers.linear.provider.render_backlog_html",
            side_effect=RuntimeError("boom"),
        ):
            failure_text = p.format_context(_SAMPLE_DATA)

        self.assertTrue(success_text.startswith(expected_markdown))
        self.assertEqual(failure_text, expected_markdown)


if __name__ == "__main__":
    unittest.main()
