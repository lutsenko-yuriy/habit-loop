import re
import shutil
import subprocess


def _find_gh() -> str:
    return shutil.which("gh") or "/opt/homebrew/bin/gh"


def _get_github_repo() -> str:
    try:
        r = subprocess.run(
            ["git", "remote", "get-url", "origin"],
            capture_output=True, text=True, timeout=5,
        )
        m = re.search(r"github\.com[:/](.+?)(?:\.git)?$", r.stdout.strip())
        return m.group(1) if m else ""
    except Exception:
        return ""


def _execute_github_tool(name: str, args: dict) -> str:
    gh = _find_gh()
    try:
        if name == "github_get_pr":
            r = subprocess.run(
                [gh, "pr", "view", str(args["number"]),
                 "--json", "title,state,headRefOid,files,body"],
                capture_output=True, text=True, timeout=30,
            )
            return r.stdout or r.stderr

        if name == "github_get_pr_diff":
            r = subprocess.run(
                [gh, "pr", "diff", str(args["number"])],
                capture_output=True, text=True, timeout=30,
            )
            diff = r.stdout or r.stderr
            return (diff[:100_000] + "\n...[truncated]") if len(diff) > 100_000 else diff

        if name == "github_create_pr_comment":
            r = subprocess.run(
                [gh, "pr", "comment", str(args["number"]), "--body", args["body"]],
                capture_output=True, text=True, timeout=30,
            )
            return r.stdout + r.stderr

        if name == "github_create_pr_review_comment":
            repo = _get_github_repo()
            if not repo:
                return "[github tool error] could not resolve owner/repo from git remote"
            r = subprocess.run(
                [
                    gh, "api", f"repos/{repo}/pulls/{args['number']}/comments",
                    "--method", "POST",
                    "--field", f"body={args['body']}",
                    "--field", f"commit_id={args['commit_id']}",
                    "--field", f"path={args['path']}",
                    "--field", f"line={args['line']}",
                    "--field", "side=RIGHT",
                ],
                capture_output=True, text=True, timeout=30,
            )
            return r.stdout + r.stderr

        if name == "github_merge_pr":
            method = args.get("method", "squash")
            r = subprocess.run(
                [gh, "pr", "merge", str(args["number"]), f"--{method}"],
                capture_output=True, text=True, timeout=60,
            )
            return r.stdout + r.stderr

    except Exception as e:
        return f"[github tool error] {e}"

    return f"Unknown GitHub tool: {name}"
