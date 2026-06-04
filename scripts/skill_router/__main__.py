import os
import sys
from pathlib import Path

from .constants import MAX_TOOL_TURNS
from .frontmatter import read_frontmatter, lookup_lmstudio_model, _normalize_model_name
from .streaming import model_loaded, stream_completion
from .linear_client import fetch_linear_context, format_linear_context
from .tool_loop import _build_tools, chat_completion_with_tools


def main():
    if len(sys.argv) < 2:
        print("Usage: skill_router.py <skill_path> [--args <extra>]", file=sys.stderr)
        sys.exit(2)

    skill_path = sys.argv[1]

    extra_args = ""
    if "--args" in sys.argv:
        idx = sys.argv.index("--args")
        extra_args = " ".join(sys.argv[idx + 1:]).strip()

    if not Path(skill_path).exists():
        print(f"[skill_router] Skill file not found: {skill_path}", file=sys.stderr)
        sys.exit(2)

    effort, reasoning, needs_session_tools, context, tool_groups, max_turns, body = read_frontmatter(skill_path)
    if not effort or not reasoning:
        print(f"[skill_router] Could not parse frontmatter in {skill_path}", file=sys.stderr)
        sys.exit(2)

    if needs_session_tools:
        print(
            f"[skill_router] {skill_path} requires session tools (MCP/Bash/Edit) — "
            "must run inside Claude Code, not via LM Studio",
            file=sys.stderr,
        )
        sys.exit(2)

    if context == "linear":
        api_key = os.environ.get("LINEAR_API_KEY")
        if not api_key:
            print(
                "[skill_router] LINEAR_API_KEY not set — required for skills with context: linear",
                file=sys.stderr,
            )
            sys.exit(2)
        try:
            context_data = fetch_linear_context(api_key)
            body = f"{format_linear_context(context_data)}\n\n{body}"
        except Exception as e:
            print(f"[skill_router] Failed to fetch Linear context: {e}", file=sys.stderr)
            sys.exit(1)

    linear_api_key = os.environ.get("LINEAR_API_KEY")
    if "linear" in tool_groups and not linear_api_key:
        print(
            "[skill_router] LINEAR_API_KEY not set — required for skills with tools: linear",
            file=sys.stderr,
        )
        sys.exit(2)

    model_name = lookup_lmstudio_model(effort, reasoning)
    if not model_name:
        print(
            f"[skill_router] No lm-studio mapping for {effort}+{reasoning} in docs/MODEL_TIERS.md",
            file=sys.stderr,
        )
        sys.exit(2)

    if not model_loaded(model_name):
        print(
            f"[skill_router] LM Studio unavailable or model not loaded: {model_name}",
            file=sys.stderr,
        )
        sys.exit(1)

    api_model_name = _normalize_model_name(model_name)
    prompt = f"{body}\n\n---\n\n{extra_args}" if extra_args else body

    tools = _build_tools(tool_groups)
    if tools:
        success = chat_completion_with_tools(
            api_model_name, prompt, tools, linear_api_key=linear_api_key, max_turns=max_turns
        )
    else:
        success = stream_completion(api_model_name, prompt)

    if not success:
        sys.exit(1)


if __name__ == "__main__":
    main()
