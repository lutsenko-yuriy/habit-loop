import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from skill_router.providers.linear.html_view import (
    open_in_browser,
    render_backlog_html,
    write_backlog_html,
)
from .fixtures import FAKE_LINEAR_DATA


class TestRenderBacklogHtml(unittest.TestCase):

    def test_every_identifier_appears(self):
        result = render_backlog_html(FAKE_LINEAR_DATA)
        for issue in FAKE_LINEAR_DATA["issues"]:
            self.assertIn(issue["identifier"], result)

    def test_every_title_appears(self):
        result = render_backlog_html(FAKE_LINEAR_DATA)
        for issue in FAKE_LINEAR_DATA["issues"]:
            self.assertIn(issue["title"], result)

    def test_every_status_name_appears(self):
        result = render_backlog_html(FAKE_LINEAR_DATA)
        for issue in FAKE_LINEAR_DATA["issues"]:
            self.assertIn(issue["state"]["name"], result)

    def test_type_labels_appear(self):
        result = render_backlog_html(FAKE_LINEAR_DATA)
        self.assertIn("Bug", result)
        self.assertIn("Feature", result)
        self.assertIn("Unlabeled", result)

    def test_issue_with_url_renders_link(self):
        result = render_backlog_html(FAKE_LINEAR_DATA)
        self.assertIn('<a href="https://linear.app/habit-loop/issue/HAB-10"', result)

    def test_issue_without_url_renders_plain_text_no_anchor(self):
        result = render_backlog_html(FAKE_LINEAR_DATA)
        # HAB-12 has an empty url — its identifier must not be wrapped in <a href
        lines_with_hab12 = [line for line in result.splitlines() if "HAB-12" in line]
        self.assertTrue(lines_with_hab12)
        for line in lines_with_hab12:
            if ">HAB-12<" in line or "HAB-12<" in line:
                self.assertNotIn("<a href", line)

    def test_null_description_renders_title_with_no_none_literal(self):
        result = render_backlog_html(FAKE_LINEAR_DATA)
        for line in result.splitlines():
            if "Unlabeled issue" in line:
                self.assertNotIn("None", line)
                self.assertNotIn("— <", line)

    def test_title_with_html_is_escaped(self):
        data = {
            **FAKE_LINEAR_DATA,
            "issues": [
                {
                    "identifier": "HAB-99",
                    "title": "<script>alert(1)</script>",
                    "description": None,
                    "url": "https://linear.app/habit-loop/issue/HAB-99",
                    "state": {"name": "Backlog", "type": "backlog"},
                    "labels": {"nodes": []},
                }
            ],
        }
        result = render_backlog_html(data)
        self.assertNotIn("<script>alert(1)</script>", result)
        self.assertIn("&lt;script&gt;", result)

    def test_url_is_escaped(self):
        data = {
            **FAKE_LINEAR_DATA,
            "issues": [
                {
                    "identifier": "HAB-99",
                    "title": "Injection test",
                    "description": None,
                    "url": 'https://linear.app/"><script>alert(1)</script>',
                    "state": {"name": "Backlog", "type": "backlog"},
                    "labels": {"nodes": []},
                }
            ],
        }
        result = render_backlog_html(data)
        self.assertNotIn('"><script>alert(1)</script>', result)

    def test_multi_label_issue_picks_priority_order_first_match(self):
        data = {
            **FAKE_LINEAR_DATA,
            "issues": [
                {
                    "identifier": "HAB-98",
                    "title": "Multi label",
                    "description": None,
                    "url": "",
                    "state": {"name": "Backlog", "type": "backlog"},
                    "labels": {"nodes": [{"name": "Feature"}, {"name": "Bug"}]},
                }
            ],
        }
        result = render_backlog_html(data)
        rows = [line for line in result.splitlines() if "HAB-98" in line]
        row_text = " ".join(rows)
        self.assertIn("Bug", row_text)

    def test_milestone_name_and_progress_in_header(self):
        result = render_backlog_html(FAKE_LINEAR_DATA)
        self.assertIn("v1.0.0", result)
        self.assertIn("75%", result)

    def test_empty_milestone_list_renders_none_without_percent(self):
        data = {**FAKE_LINEAR_DATA, "milestones": []}
        result = render_backlog_html(data)
        self.assertIn("none", result.lower())

    def test_self_contained_document(self):
        result = render_backlog_html(FAKE_LINEAR_DATA)
        self.assertTrue(result.startswith("<!DOCTYPE html>"))
        self.assertNotIn("<script src=", result)
        self.assertNotIn("<link ", result)
        self.assertNotIn("cdn.", result)


class TestWriteBacklogHtml(unittest.TestCase):

    def test_round_trips_through_tempfile(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "backlog.local.html"
            returned = write_backlog_html("<!DOCTYPE html><html></html>", path)
            self.assertEqual(returned, path)
            self.assertEqual(path.read_text(), "<!DOCTYPE html><html></html>")


class TestOpenInBrowser(unittest.TestCase):

    def test_noop_when_disabled_via_env(self):
        with patch.dict(os.environ, {"HL_BACKLOG_HTML_OPEN": "off"}):
            with patch("skill_router.providers.linear.html_view.subprocess.run") as mock_run:
                result = open_in_browser(Path("/tmp/backlog.local.html"))
        mock_run.assert_not_called()
        self.assertFalse(result)

    def test_calls_open_on_darwin(self):
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop("HL_BACKLOG_HTML_OPEN", None)
            with patch("skill_router.providers.linear.html_view.sys.platform", "darwin"):
                with patch("skill_router.providers.linear.html_view.subprocess.run") as mock_run:
                    result = open_in_browser(Path("/tmp/backlog.local.html"))
        mock_run.assert_called_once()
        args = mock_run.call_args[0][0]
        self.assertEqual(args[0], "open")
        self.assertTrue(result)


if __name__ == "__main__":
    unittest.main()
