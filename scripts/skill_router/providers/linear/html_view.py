import os
import subprocess
import sys
from html import escape
from pathlib import Path

from .context import first_line

_TYPE_PRIORITY = ("Bug", "Tech Debt", "Feature", "Improvement")


def _issue_type(issue: dict) -> str:
    label_names = {label["name"] for label in issue.get("labels", {}).get("nodes", [])}
    for candidate in _TYPE_PRIORITY:
        if candidate in label_names:
            return candidate
    return "Unlabeled"


def _issue_description(issue: dict) -> str:
    title = issue.get("title", "")
    desc = first_line(issue.get("description"))
    return f"{title} — {desc}" if desc else title


def _issue_number_cell(issue: dict) -> str:
    identifier = escape(issue.get("identifier", ""))
    url = issue.get("url") or ""
    if url:
        return f'<a href="{escape(url)}">{identifier}</a>'
    return identifier


def _issue_row(issue: dict) -> str:
    identifier = issue.get("identifier", "")
    digits = "".join(ch for ch in identifier if ch.isdigit())
    sort_key = digits or "0"
    return (
        "<tr>"
        f'<td data-sort="{sort_key}">{_issue_number_cell(issue)}</td>'
        f"<td>{escape(_issue_description(issue))}</td>"
        f"<td>{escape(_issue_type(issue))}</td>"
        f'<td>{escape(issue.get("state", {}).get("name", ""))}</td>'
        "</tr>"
    )


def _milestone_header(milestones: list) -> str:
    active = next(
        (m for m in milestones if m.get("status") not in ("done", "overdue", "canceled")),
        None,
    )
    if active:
        return f"Active milestone: {escape(str(active.get('name', '')))} ({active.get('progress', 0)}% complete)"
    return "Active milestone: none"


_STYLE = """
:root { color-scheme: light dark; }
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 2rem; }
table { border-collapse: collapse; width: 100%; }
th, td { text-align: left; padding: 0.5rem 0.75rem; border-bottom: 1px solid #8884; }
th { cursor: pointer; user-select: none; }
th[aria-sort]::after { content: " " attr(aria-sort); font-size: 0.75em; opacity: 0.6; }
"""

_SCRIPT = """
document.querySelectorAll('th[data-col]').forEach(function (th) {
  th.addEventListener('click', function () {
    var table = th.closest('table');
    var tbody = table.querySelector('tbody');
    var col = parseInt(th.getAttribute('data-col'), 10);
    var numeric = th.getAttribute('data-numeric') === 'true';
    var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr'));
    var ascending = th.getAttribute('aria-sort') !== 'ascending';
    table.querySelectorAll('th').forEach(function (h) { h.removeAttribute('aria-sort'); });
    rows.sort(function (a, b) {
      var ca = a.children[col];
      var cb = b.children[col];
      var va = numeric ? parseFloat(ca.getAttribute('data-sort') || '0') : ca.textContent.trim().toLowerCase();
      var vb = numeric ? parseFloat(cb.getAttribute('data-sort') || '0') : cb.textContent.trim().toLowerCase();
      if (va < vb) return ascending ? -1 : 1;
      if (va > vb) return ascending ? 1 : -1;
      return 0;
    });
    rows.forEach(function (row) { tbody.appendChild(row); });
    th.setAttribute('aria-sort', ascending ? 'ascending' : 'descending');
  });
});
"""


def render_backlog_html(data: dict) -> str:
    issues = data.get("issues", [])
    milestones = data.get("milestones", [])
    rows = "\n".join(_issue_row(issue) for issue in issues)
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Habit Loop backlog</title>
<style>{_STYLE}</style>
</head>
<body>
<h1>Habit Loop backlog</h1>
<p>{_milestone_header(milestones)}</p>
<p>{len(issues)} issue(s)</p>
<table>
<thead>
<tr>
<th data-col="0" data-numeric="true">#</th>
<th data-col="1">Description</th>
<th data-col="2">Type</th>
<th data-col="3">Status</th>
</tr>
</thead>
<tbody>
{rows}
</tbody>
</table>
<script>{_SCRIPT}</script>
</body>
</html>
"""


def write_backlog_html(html: str, path: Path) -> Path:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(html)
    return path


def open_in_browser(path: Path) -> bool:
    if os.environ.get("HL_BACKLOG_HTML_OPEN") == "off":
        return False
    if sys.platform == "darwin":
        subprocess.run(["open", str(path)], check=False)
        return True
    if sys.platform.startswith("linux"):
        subprocess.run(["xdg-open", str(path)], check=False)
        return True
    return False
