import unittest
from unittest.mock import patch

from skill_router.providers.linear.context import (
    ISSUES_QUERY,
    active_milestone,
    fetch_linear_context,
    first_line,
    format_linear_context,
)
from .fixtures import FAKE_LINEAR_DATA


_FAKE_PROJECT_ID = "test-project-id"


class TestFetchLinearContext(unittest.TestCase):

    def _mock_graphql(self, issues_nodes, milestone_nodes):
        def fake_graphql(api_key, query, variables=None):
            if "issues" in query:
                return {"data": {"issues": {"nodes": issues_nodes}}}
            return {"data": {"project": {"projectMilestones": {"nodes": milestone_nodes}}}}
        return fake_graphql

    def test_returns_issues_and_milestones(self):
        with patch(
            "skill_router.providers.linear.context._linear_graphql",
            side_effect=self._mock_graphql(
                [{"identifier": "HAB-1", "title": "T", "state": {"name": "Backlog", "type": "backlog"}, "labels": {"nodes": []}}],
                [{"name": "v1.0.0", "progress": 50, "targetDate": "2026-06-01", "status": "inProgress"}],
            ),
        ):
            result = fetch_linear_context("key", _FAKE_PROJECT_ID)
        self.assertEqual(len(result["issues"]), 1)
        self.assertEqual(len(result["milestones"]), 1)

    def test_returns_empty_lists_on_missing_data(self):
        with patch(
            "skill_router.providers.linear.context._linear_graphql",
            return_value={"data": {}},
        ):
            result = fetch_linear_context("key", _FAKE_PROJECT_ID)
        self.assertEqual(result["issues"], [])
        self.assertEqual(result["milestones"], [])

    def test_propagates_exception_on_network_error(self):
        with patch(
            "skill_router.providers.linear.context._linear_graphql",
            side_effect=Exception("timeout"),
        ):
            with self.assertRaises(Exception):
                fetch_linear_context("key", _FAKE_PROJECT_ID)


class TestFormatLinearContext(unittest.TestCase):

    def test_active_milestone_shown(self):
        result = format_linear_context(FAKE_LINEAR_DATA)
        self.assertIn("v1.0.0", result)
        self.assertIn("75%", result)

    def test_no_active_milestone_when_all_done(self):
        data = {**FAKE_LINEAR_DATA, "milestones": [{"name": "v1.0.0", "progress": 100, "status": "done", "targetDate": "2026-01-01"}]}
        result = format_linear_context(data)
        self.assertIn("Active milestone: none", result)

    def test_issues_grouped_by_label(self):
        result = format_linear_context(FAKE_LINEAR_DATA)
        self.assertIn("HAB-10", result)
        self.assertIn("HAB-11", result)
        self.assertIn("HAB-12", result)

    def test_description_included_in_issue_line(self):
        result = format_linear_context(FAKE_LINEAR_DATA)
        self.assertIn("App crashes on launch", result)
        self.assertIn("New user-facing capability", result)

    def test_none_description_omitted(self):
        result = format_linear_context(FAKE_LINEAR_DATA)
        for line in result.splitlines():
            if "HAB-12" in line:
                self.assertNotIn("None", line)

    def test_no_milestone_shows_none_without_percentage(self):
        data = {**FAKE_LINEAR_DATA, "milestones": []}
        result = format_linear_context(data)
        self.assertIn("Active milestone: none", result)
        self.assertNotIn("%", result.split("Active milestone:")[1].split("\n")[0])

    def test_no_recently_completed_placeholder(self):
        result = format_linear_context(FAKE_LINEAR_DATA)
        self.assertNotIn("Recently completed", result)

    def test_output_has_context_markers(self):
        result = format_linear_context(FAKE_LINEAR_DATA)
        self.assertIn("=== PRE-FETCHED BACKLOG", result)
        self.assertIn("=== END PRE-FETCHED BACKLOG ===", result)


class TestIssuesQueryUrlField(unittest.TestCase):

    def test_query_requests_url_field(self):
        self.assertIn("url", ISSUES_QUERY)


class TestFirstLine(unittest.TestCase):

    def test_returns_first_line_of_multiline_text(self):
        self.assertEqual(first_line("first\nsecond\nthird"), "first")

    def test_strips_surrounding_whitespace(self):
        self.assertEqual(first_line("  padded  \nmore"), "padded")

    def test_truncates_to_max_len(self):
        self.assertEqual(first_line("a" * 200), "a" * 120)

    def test_truncates_to_custom_max_len(self):
        self.assertEqual(first_line("a" * 20, max_len=5), "a" * 5)

    def test_none_input_returns_empty_string(self):
        self.assertEqual(first_line(None), "")

    def test_empty_string_returns_empty_string(self):
        self.assertEqual(first_line(""), "")


class TestActiveMilestone(unittest.TestCase):

    def test_returns_first_milestone_not_done_overdue_or_canceled(self):
        milestones = [
            {"name": "done one", "status": "done"},
            {"name": "the active one", "status": "started"},
        ]
        self.assertEqual(active_milestone(milestones)["name"], "the active one")

    def test_returns_none_when_all_milestones_are_terminal(self):
        milestones = [
            {"name": "done one", "status": "done"},
            {"name": "overdue one", "status": "overdue"},
            {"name": "canceled one", "status": "canceled"},
        ]
        self.assertIsNone(active_milestone(milestones))

    def test_returns_none_for_empty_list(self):
        self.assertIsNone(active_milestone([]))


if __name__ == "__main__":
    unittest.main()
