import json
import sys
import urllib.request

from .constants import LMSTUDIO_BASE, MAX_TOOL_TURNS
from .streaming import _auth_headers
from .linear_client import _execute_linear_tool
from .github_client import _execute_github_tool
from .files_client import _execute_files_tool

_TOOLS_LINEAR = [
    {
        "type": "function",
        "function": {
            "name": "linear_list_issues",
            "description": "List open issues from the Linear workspace",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "linear_get_issue",
            "description": "Get full details of a Linear issue by identifier (e.g. HAB-42)",
            "parameters": {
                "type": "object",
                "properties": {
                    "identifier": {"type": "string", "description": "Issue identifier e.g. HAB-42"},
                },
                "required": ["identifier"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "linear_update_issue_state",
            "description": "Move a Linear issue to a new workflow state",
            "parameters": {
                "type": "object",
                "properties": {
                    "identifier": {"type": "string", "description": "Issue identifier e.g. HAB-42"},
                    "state_name": {
                        "type": "string",
                        "description": "Target state name e.g. 'In Review', 'In QA', 'Done', 'In Progress'",
                    },
                },
                "required": ["identifier", "state_name"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "linear_create_comment",
            "description": "Post a comment on a Linear issue",
            "parameters": {
                "type": "object",
                "properties": {
                    "identifier": {"type": "string", "description": "Issue identifier e.g. HAB-42"},
                    "body": {"type": "string", "description": "Comment text (Markdown)"},
                },
                "required": ["identifier", "body"],
            },
        },
    },
]

_TOOLS_GITHUB = [
    {
        "type": "function",
        "function": {
            "name": "github_get_pr",
            "description": "Get PR details: title, state, head commit SHA, and changed files",
            "parameters": {
                "type": "object",
                "properties": {
                    "number": {"type": "integer", "description": "PR number"},
                },
                "required": ["number"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "github_get_pr_diff",
            "description": "Get the full unified diff of a PR (truncated at 100 KB)",
            "parameters": {
                "type": "object",
                "properties": {"number": {"type": "integer"}},
                "required": ["number"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "github_create_pr_comment",
            "description": "Post a general comment on a PR",
            "parameters": {
                "type": "object",
                "properties": {
                    "number": {"type": "integer"},
                    "body": {"type": "string"},
                },
                "required": ["number", "body"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "github_create_pr_review_comment",
            "description": "Post an inline review comment on a specific file and line in a PR",
            "parameters": {
                "type": "object",
                "properties": {
                    "number": {"type": "integer"},
                    "commit_id": {"type": "string", "description": "Head commit SHA of the PR"},
                    "path": {"type": "string", "description": "File path relative to repo root"},
                    "line": {"type": "integer", "description": "Line number in the diff"},
                    "body": {"type": "string"},
                },
                "required": ["number", "commit_id", "path", "line", "body"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "github_merge_pr",
            "description": "Merge a pull request",
            "parameters": {
                "type": "object",
                "properties": {
                    "number": {"type": "integer"},
                    "method": {
                        "type": "string",
                        "enum": ["merge", "squash", "rebase"],
                        "description": "Merge method (default: squash)",
                    },
                },
                "required": ["number"],
            },
        },
    },
]

_TOOLS_FILES = [
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Read a file from the project root",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "Path relative to project root"},
                },
                "required": ["path"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "write_file",
            "description": "Write (create or overwrite) a file in the project root",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string"},
                    "content": {"type": "string"},
                },
                "required": ["path", "content"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "run_bash",
            "description": "Run a shell command in the project root and return stdout + stderr",
            "parameters": {
                "type": "object",
                "properties": {"command": {"type": "string"}},
                "required": ["command"],
            },
        },
    },
]

_KNOWN_TOOL_GROUPS = {"linear", "github", "files"}


def _build_tools(groups: list) -> list:
    tools = []
    for g in groups:
        if g == "linear":
            tools.extend(_TOOLS_LINEAR)
        elif g == "github":
            tools.extend(_TOOLS_GITHUB)
        elif g == "files":
            tools.extend(_TOOLS_FILES)
        else:
            print(f"[skill_router] Unknown tool group '{g}' — skipping", file=sys.stderr)
    return tools


def _execute_tool(name: str, args: dict, *, linear_api_key: str = None) -> str:
    if name.startswith("linear_"):
        if not linear_api_key:
            return "[tool error] LINEAR_API_KEY not set — required for linear_* tools"
        return _execute_linear_tool(name, args, linear_api_key)
    if name.startswith("github_"):
        return _execute_github_tool(name, args)
    if name in ("read_file", "write_file", "run_bash"):
        return _execute_files_tool(name, args)
    return f"[tool error] unknown tool: {name}"


def chat_completion_with_tools(
    model_name: str,
    prompt: str,
    tools: list,
    *,
    linear_api_key: str = None,
    max_turns: int = MAX_TOOL_TURNS,
) -> bool:
    messages = [{"role": "user", "content": prompt}]

    for turn in range(max_turns):
        payload = json.dumps({
            "model": model_name,
            "messages": messages,
            "tools": tools,
            "tool_choice": "auto",
            "stream": False,
        }).encode()
        req = urllib.request.Request(
            f"{LMSTUDIO_BASE}/chat/completions",
            data=payload,
            headers={"Content-Type": "application/json", **_auth_headers()},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=300) as resp:
                data = json.load(resp)
        except Exception as e:
            print(f"\n[skill_router] Tool loop error on turn {turn + 1}: {e}", file=sys.stderr)
            return False

        if not data.get("choices"):
            print("[skill_router] Empty response from model", file=sys.stderr)
            return False

        choice = data["choices"][0]
        msg = choice["message"]
        finish_reason = choice.get("finish_reason", "stop")
        tool_calls = msg.get("tool_calls") or []

        if tool_calls and finish_reason in ("tool_calls", None, ""):
            messages.append(msg)
            for tc in tool_calls:
                fn_name = tc["function"]["name"]
                try:
                    fn_args = json.loads(tc["function"]["arguments"])
                except (json.JSONDecodeError, TypeError):
                    fn_args = {}
                print(
                    f"[tool:{turn + 1}] {fn_name}({json.dumps(fn_args)[:120]})",
                    file=sys.stderr,
                )
                result = _execute_tool(fn_name, fn_args, linear_api_key=linear_api_key)
                messages.append({
                    "role": "tool",
                    "tool_call_id": tc["id"],
                    "content": result if isinstance(result, str) else json.dumps(result),
                })
        else:
            content = msg.get("content") or ""
            print(content, flush=True)
            print()
            return True

    print(f"[skill_router] Tool loop hit max turns ({max_turns})", file=sys.stderr)
    return False
