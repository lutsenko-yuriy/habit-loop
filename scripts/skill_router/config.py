from __future__ import annotations

import os
import sys
from dataclasses import dataclass
from pathlib import Path

try:
    import tomllib
except ImportError:
    tomllib = None

# Resolved against this file, not cwd — a relative default would miss the
# real toml (and fail open) when invoked from outside the repo root.
_DEFAULT_TOML_PATH = Path(__file__).resolve().parents[2] / "skill_router.toml"


@dataclass(frozen=True)
class Config:
    linear_api_key: str | None
    linear_project_id: str | None
    lmstudio_base: str
    model_tiers_path: str
    local_models_enabled: bool


def _load_toml(path: Path) -> tuple[dict, bool]:
    """Returns (data, load_ok); load_ok is False when the file exists but couldn't be read (see CLAUDE.local.md's python3.12 note)."""
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


def load_config(toml_path: str | Path = _DEFAULT_TOML_PATH) -> Config:
    data, load_ok = _load_toml(Path(toml_path))
    local_models_enabled_raw = data.get("core", {}).get("local_models_enabled", True)
    if load_ok and isinstance(local_models_enabled_raw, bool):
        local_models_enabled = local_models_enabled_raw
    else:
        # Fail closed on any unverified/non-bool value — never default to enabled.
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
