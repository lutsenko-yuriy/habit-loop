import subprocess
from pathlib import Path


def _execute_files_tool(name: str, args: dict) -> str:
    try:
        if name == "read_file":
            return Path(args["path"]).read_text()

        if name == "write_file":
            p = Path(args["path"])
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(args["content"])
            return f"Written {args['path']}"

        if name == "run_bash":
            r = subprocess.run(
                args["command"], shell=True,
                capture_output=True, text=True, timeout=120,
            )
            out = r.stdout
            if r.stderr:
                out += f"\n[stderr]\n{r.stderr}"
            return out or "(no output)"

    except Exception as e:
        return f"[files tool error] {e}"

    return f"Unknown files tool: {name}"
