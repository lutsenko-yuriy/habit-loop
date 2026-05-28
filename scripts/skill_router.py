# -*- coding: utf-8 -*-
#!/usr/bin/env python3
"""
skill_router.py — routes a skill to the LM Studio local OpenAI-compatible API.

Usage:
    python scripts/skill_router.py <skill_path> [--args <extra>]

Arguments:
    skill_path   Path to the SKILL.md file (e.g. skills/manage/ship/SKILL.md)
    --args       Optional extra text appended to the skill prompt (e.g. "PR #115")

Exit codes:
    0  Skill executed successfully
    1  LM Studio unavailable or the mapped model is not loaded
    2  Skill file not found, unparseable frontmatter, or no lm-studio mapping
"""

import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

LMSTUDIO_BASE = "http://localhost:1234/v1"
MODEL_TIERS_PATH = "docs/MODEL_TIERS.md"


def read_frontmatter(skill_path: str):
    """Return (effort, reasoning, body) parsed from a SKILL.md file."""
    text = Path(skill_path).read_text()
    m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not m:
        return None, None, text
    fm = m.group(1)
    effort = re.search(r"^effort:\s*(\S+)", fm, re.MULTILINE)
    reasoning = re.search(r"^reasoning:\s*(\S+)", fm, re.MULTILINE)
    return (
        effort.group(1) if effort else None,
        reasoning.group(1) if reasoning else None,
        text[m.end():],
    )


def _normalize_model_name(name: str) -> str:
    """Strip quantization annotations (e.g. '(MLX, 4-bit)') and lowercase."""
    return re.split(r"[\s(]", name.strip())[0].lower()


def lookup_lmstudio_model(effort: str, reasoning: str):
    """
    Scan the Active mapping table in MODEL_TIERS.md.
    Returns the model name if the alias is 'lm-studio', else None.

    Expected table row format (after splitting on '|' and stripping):
        index 0: ''   index 1: Effort   index 2: Reasoning
        index 3: Model   index 4: alias   index 5: ''
    Rows with fewer than 5 parts (header separators, blank lines) are skipped.
    """
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
        # Skip header and separator rows (they won't match effort/reasoning values)
        if row_effort == effort and row_reasoning == reasoning:
            clean_alias = alias.strip("`")
            return model if clean_alias == "lm-studio" else None

    return None


def model_loaded(model_name: str) -> bool:
    """Return True if LM Studio is reachable and the model is loaded.

    Compares normalized base names (strips quantization annotations like
    '(MLX, 4-bit)') so 'qwen/qwen3-8b (MLX, 4-bit)' matches a LM Studio
    id like 'qwen/qwen3-8b' or 'qwen/qwen3-8b-mlx'.
    """
    try:
        req = urllib.request.Request(f"{LMSTUDIO_BASE}/models")
        with urllib.request.urlopen(req, timeout=3) as resp:
            data = json.load(resp)
        loaded_ids = [m["id"] for m in data.get("data", [])]
        needle = _normalize_model_name(model_name)
        return any(
            needle in _normalize_model_name(mid) or _normalize_model_name(mid) in needle
            for mid in loaded_ids
        )
    except Exception:
        return False


def stream_completion(model_name: str, prompt: str) -> bool:
    """POST a streaming chat completion and write chunks to stdout."""
    payload = json.dumps(
        {
            "model": model_name,
            "messages": [{"role": "user", "content": prompt}],
            "stream": True,
        }
    ).encode()
    req = urllib.request.Request(
        f"{LMSTUDIO_BASE}/chat/completions",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            for raw_line in resp:
                line = raw_line.decode().strip()
                if not line.startswith("data: "):
                    continue
                payload_str = line[6:]
                if payload_str == "[DONE]":
                    break
                try:
                    chunk = json.loads(payload_str)
                    content = chunk["choices"][0]["delta"].get("content", "")
                    if content:
                        print(content, end="", flush=True)
                except (json.JSONDecodeError, KeyError, IndexError, TypeError):
                    pass
        print()  # trailing newline
        return True
    except Exception as e:
        print(f"\n[skill_router] Streaming error: {e}", file=sys.stderr)
        return False


def main():
    if len(sys.argv) < 2:
        print("Usage: skill_router.py <skill_path> [--args <extra>]", file=sys.stderr)
        sys.exit(2)

    skill_path = sys.argv[1]

    # Parse --args flag (everything after --args is the extra context)
    extra_args = ""
    if "--args" in sys.argv:
        idx = sys.argv.index("--args")
        extra_args = " ".join(sys.argv[idx + 1:]).strip()

    if not Path(skill_path).exists():
        print(f"[skill_router] Skill file not found: {skill_path}", file=sys.stderr)
        sys.exit(2)

    effort, reasoning, body = read_frontmatter(skill_path)
    if not effort or not reasoning:
        print(f"[skill_router] Could not parse frontmatter in {skill_path}", file=sys.stderr)
        sys.exit(2)

    model_name = lookup_lmstudio_model(effort, reasoning)
    if not model_name:
        print(
            f"[skill_router] No lm-studio mapping for {effort}+{reasoning} in {MODEL_TIERS_PATH}",
            file=sys.stderr,
        )
        sys.exit(2)

    if not model_loaded(model_name):
        print(
            f"[skill_router] LM Studio unavailable or model not loaded: {model_name}",
            file=sys.stderr,
        )
        sys.exit(1)

    # Strip quantization annotations (e.g. "(MLX, 4-bit)") — LM Studio rejects them
    api_model_name = _normalize_model_name(model_name)
    prompt = f"{body}\n\n---\n\n{extra_args}" if extra_args else body

    if not stream_completion(api_model_name, prompt):
        sys.exit(1)


if __name__ == "__main__":
    main()
