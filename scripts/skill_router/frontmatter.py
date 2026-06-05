import re
import sys
from pathlib import Path

from .constants import MAX_TOOL_TURNS, MODEL_TIERS_PATH, _normalize_model_name  # noqa: F401


def read_frontmatter(skill_path: str):
    """Return (effort, reasoning, needs_session_tools, context, tools, max_turns, body)."""
    text = Path(skill_path).read_text()
    m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not m:
        return None, None, False, None, [], MAX_TOOL_TURNS, text
    fm = m.group(1)
    effort = re.search(r"^effort:\s*(\S+)", fm, re.MULTILINE)
    reasoning = re.search(r"^reasoning:\s*(\S+)", fm, re.MULTILINE)
    needs_session_tools = bool(re.search(r"^needs_session_tools:\s*true", fm, re.MULTILINE))
    context_match = re.search(r"^context:\s*(\S+)", fm, re.MULTILINE)
    tools_match = re.search(r"^tools:\s*(.+)$", fm, re.MULTILINE)
    tools = [t.strip() for t in tools_match.group(1).split(",")] if tools_match else []
    max_turns_match = re.search(r"^max_turns:\s*(\d+)", fm, re.MULTILINE)
    max_turns = int(max_turns_match.group(1)) if max_turns_match else MAX_TOOL_TURNS
    return (
        effort.group(1) if effort else None,
        reasoning.group(1) if reasoning else None,
        needs_session_tools,
        context_match.group(1) if context_match else None,
        tools,
        max_turns,
        text[m.end():],
    )


def lookup_lmstudio_model(effort: str, reasoning: str):
    """Return the model name if the tier maps to lm-studio, else None."""
    try:
        tiers_text = Path(MODEL_TIERS_PATH).read_text()
    except FileNotFoundError:
        print(f"[skill_router] {MODEL_TIERS_PATH} not found", file=sys.stderr)
        return None

    section = re.search(r"## Active mapping\n(.*?)\n---", tiers_text, re.DOTALL)
    if not section:
        print(f"[skill_router] '## Active mapping' section not found in {MODEL_TIERS_PATH}", file=sys.stderr)
        return None

    for line in section.group(1).splitlines():
        parts = [p.strip() for p in line.split("|")]
        if len(parts) < 5:
            continue
        row_effort, row_reasoning, model, alias = parts[1], parts[2], parts[3], parts[4]
        if row_effort == effort and row_reasoning == reasoning:
            return model if alias.strip("`") == "lm-studio" else None

    return None
