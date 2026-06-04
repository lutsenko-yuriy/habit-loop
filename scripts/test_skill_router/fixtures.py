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

_MT = 40  # default MAX_TOOL_TURNS
_FM_PLAIN = ("RAPID", "MECHANICAL", False, None, [], _MT, "body")
_FM_SESSION_TOOLS = ("RAPID", "MECHANICAL", True, None, [], _MT, "body")
_FM_NO_EFFORT = (None, None, False, None, [], _MT, "body")
_FM_FOCUSED = ("FOCUSED", "ARCHITECTURAL", False, None, [], _MT, "body")
_FM_WITH_CONTEXT = ("RAPID", "MECHANICAL", False, "linear", [], _MT, "body")
_FM_WITH_TOOLS_LINEAR = ("RAPID", "MECHANICAL", False, None, ["linear"], _MT, "body")
_FM_WITH_TOOLS_GITHUB = ("RAPID", "MECHANICAL", False, None, ["github", "files"], _MT, "body")

FAKE_LINEAR_DATA = {
    "issues": [
        {
            "identifier": "HAB-10",
            "title": "Fix crash",
            "description": "App crashes on launch",
            "state": {"name": "Backlog", "type": "backlog"},
            "labels": {"nodes": [{"name": "Bug"}]},
        },
        {
            "identifier": "HAB-11",
            "title": "Add feature",
            "description": "New user-facing capability",
            "state": {"name": "Backlog", "type": "backlog"},
            "labels": {"nodes": [{"name": "Feature"}]},
        },
        {
            "identifier": "HAB-12",
            "title": "Unlabeled issue",
            "description": None,
            "state": {"name": "Backlog", "type": "backlog"},
            "labels": {"nodes": []},
        },
    ],
    "milestones": [
        {"name": "v1.0.0", "progress": 75, "targetDate": "2026-06-01", "status": "inProgress"},
    ],
}
