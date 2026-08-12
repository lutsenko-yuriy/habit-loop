from __future__ import annotations

import os
import sys
from dataclasses import dataclass
from pathlib import Path

try:
    import tomllib
except ImportError:
    tomllib = None


@dataclass(frozen=True)
class Config:
    linear_api_key: str | None
    linear_project_id: str | None
    lmstudio_base: str
    model_tiers_path: str
    local_models_enabled: bool


def _load_toml(path: Path) -> tuple[dict, bool]:
    """Returns (data, load_ok). load_ok is False when the file exists but
    couldn't actually be read — tomllib missing (Python < 3.11, e.g. this
    machine's bare `python3`, which every .claude/commands/ stub invokes —
    see CLAUDE.local.md) or malformed TOML. A genuinely absent file is a
    fully-determined state (load_ok=True, data={}) — callers should only
    treat load_ok=False specially for anything safety-critical, since an
    unparseable-but-present file means we cannot know what it actually says."""
    if not path.exists():
        return {}, True
    if tomllib is None:
        print(
            f"[skill_router] WARNING: tomllib unavailable (Python < 3.11) — cannot read {path}. "
            "Re-run with python3.12 (see CLAUDE.local.md) to pick up its real settings.",
            file=sys.stderr,
        )
        return {}, False
    try:
        with open(path, "rb") as f:
            return tomllib.load(f), True
    except Exception as e:
        print(f"[skill_router] Warning: could not read {path}: {e}", file=sys.stderr)
        return {}, False


def load_config(toml_path: str = "skill_router.toml") -> Config:
    data, load_ok = _load_toml(Path(toml_path))
    if load_ok:
        local_models_enabled = data.get("core", {}).get("local_models_enabled", True)
    else:
        # Fail closed: an unparseable-but-present toml means we can't verify
        # the kill switch's real value — never silently fall through to
        # "enabled" (HAB-221 debrief; see skill_router.toml's own comment).
        local_models_enabled = False
    return Config(
        linear_api_key=os.environ.get("LINEAR_API_KEY"),
        linear_project_id=(
            os.environ.get("LINEAR_PROJECT_ID")
            or data.get("linear", {}).get("project_id")
        ),
        lmstudio_base=(
            os.environ.get("LMSTUDIO_BASE")
            or data.get("llm", {}).get("lmstudio_base", "http://localhost:1234/v1")
        ),
        model_tiers_path=data.get("core", {}).get("model_tiers_path", "docs/MODEL_TIERS.md"),
        local_models_enabled=local_models_enabled,
    )
