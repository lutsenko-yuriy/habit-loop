#!/usr/bin/env python3
"""Measure the token cost of context loaded via this project's `@`-include
convention (HAB-220).

An `@`-include is a `@<repo-relative-path>.md` reference that is **not**
wrapped in backticks — the convention used by `CLAUDE.md`, `AGENTS.md`, and
`docs/workflows/*.md`. A path mentioned inside backticks as prose (e.g.
`` `@docs/ARCHITECTURE.md` — code structure changed ``) is not an include and
must never be resolved as one. This is a real, not hypothetical, distinction:
`AGENTS.md`'s "Details: @docs/VERSIONING.md" (no backticks, not even a
standalone line) *does* expand, while `docs/workflows/FEATURE.md`'s
`` - `@docs/PRODUCT_SPEC.md` `` (backtick-wrapped) does *not* — confirmed by
diffing this project's own rendered session-start context against the source
files (see the plan comment and knowledge note on HAB-220).

**Recursion is capped at depth 2 from `CLAUDE.md`**, matching the same
empirical check: `CLAUDE.md` -> `@AGENTS.md` (hop 1) -> AGENTS.md's own
`@`-includes, e.g. `@docs/VERSIONING.md` (hop 2) *do* render in full, but
those hop-2 files' own further `@`-includes (e.g. `docs/workflows/FEATURE.md`'s
`@skills/shared/decision-guidelines.md`) do **not** — they show up as literal,
un-expanded `@path` text. This was verified against one real session's
rendered context, not against Claude Code's public spec, so re-check it if
this script's numbers ever look wrong after a Claude Code upgrade.

Fixed cost = everything reachable within that depth-2 cap from `CLAUDE.md`,
plus `CLAUDE.local.md` (loaded independently by the harness at session start,
not itself reached via any `@`-include) — paid on every session, regardless
of which skill (if any) runs.

Variable cost = a single `skills/**/SKILL.md`'s own `@`-include set, as read
by a human or an agent following the file manually (skill invocation does not
go through the same automatic CLAUDE.md-style expansion the harness performs
at session start — see `Skill` tool behaviour). Depth is **not** capped here:
a skill's resource files are meant to be read in full when that skill runs.

Usage:
    python3 scripts/docs/context_cost.py                 # full report: fixed + every skill's variable cost
    python3 scripts/docs/context_cost.py --fixed-only     # just the fixed-cost breakdown
    python3 scripts/docs/context_cost.py --skill <name>   # one skill's variable cost (name = its directory, e.g. "ship")
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import List, Optional, Set, Tuple

REPO_ROOT = Path(__file__).resolve().parents[2]
CLAUDE_MD = REPO_ROOT / "CLAUDE.md"
CLAUDE_LOCAL_MD = REPO_ROOT / "CLAUDE.local.md"
SKILLS_DIR = REPO_ROOT / "skills"

# Rough words->tokens ratio for markdown/English prose, matching the estimate
# used in HAB-220's plan comment. Not tokenizer-exact — good enough to compare
# before/after and to rank files, which is this script's only job.
TOKENS_PER_WORD = 1.35

# CLAUDE.md itself is hop 0; its own @-includes (e.g. AGENTS.md) are hop 1;
# AGENTS.md's own @-includes are hop 2. See module docstring for why this cap exists.
FIXED_COST_MAX_DEPTH = 2

BACKTICK_SPAN_RE = re.compile(r"`[^`\n]*`")
AT_MD_RE = re.compile(r"@(\S+\.md)")

Missing = Tuple[Path, str]  # (file that referenced it, the missing relative path)


def parse_includes(text: str) -> List[str]:
    """Repo-relative paths named by non-backtick-wrapped `@path.md` references
    in `text`, in the order they appear. Backtick-wrapped occurrences (an
    inline-code mention, not a real include) are stripped per line before
    matching."""
    includes = []
    for line in text.splitlines():
        cleaned = BACKTICK_SPAN_RE.sub("", line)
        includes.extend(match.group(1) for match in AT_MD_RE.finditer(cleaned))
    return includes


def resolve_includes(
    start: Path, repo_root: Path, max_depth: Optional[int] = None
) -> Tuple[List[Path], List[Missing]]:
    """Transitively resolve `start`'s `@`-include chain.

    `max_depth` caps how many hops from `start` are followed (`start` itself
    is depth 0); `None` means unlimited. Use this to model the real,
    depth-2-from-`CLAUDE.md` cap described in the module docstring for fixed
    cost, while leaving skill variable-cost resolution uncapped.

    Returns (files, missing): `files` is every existing file reached,
    de-duplicated and in order of first appearance (`start` first); `missing`
    is every include line whose target file does not exist, reported rather
    than raised so one broken link doesn't stop the whole measurement.
    """
    files: List[Path] = []
    seen: Set[Path] = set()
    missing: List[Missing] = []

    def visit(path: Path, depth: int) -> None:
        resolved = path.resolve()
        if resolved in seen:
            return
        seen.add(resolved)
        if not resolved.exists():
            return
        files.append(resolved)
        if max_depth is not None and depth >= max_depth:
            return
        text = resolved.read_text(encoding="utf-8")
        for rel in parse_includes(text):
            target = (repo_root / rel).resolve()
            if not target.exists():
                missing.append((resolved, rel))
                continue
            visit(target, depth + 1)

    visit(start, 0)
    return files, missing


def word_count(path: Path) -> int:
    return len(path.read_text(encoding="utf-8").split())


def to_tokens(words: int) -> int:
    return round(words * TOKENS_PER_WORD)


def fixed_cost_files(
    repo_root: Path, claude_md: Path = CLAUDE_MD, claude_local_md: Path = CLAUDE_LOCAL_MD
) -> Tuple[List[Path], List[Missing]]:
    """Files loaded on every session: `claude_md`'s `@`-include chain up to
    `FIXED_COST_MAX_DEPTH` hops, plus `claude_local_md` — appended separately
    since the harness loads it independently of any `@`-include, not as part
    of that chain."""
    files, missing = resolve_includes(claude_md, repo_root, max_depth=FIXED_COST_MAX_DEPTH)
    seen = set(files)
    if claude_local_md.exists():
        resolved_local = claude_local_md.resolve()
        if resolved_local not in seen:
            files.append(resolved_local)
    return files, missing


def iter_skill_files(skills_dir: Path) -> List[Path]:
    return sorted(skills_dir.rglob("SKILL.md"))


def skill_name(skill_md: Path) -> str:
    """The skill's identifying directory name, e.g. `.../manage/ship/SKILL.md` -> "ship"."""
    return skill_md.parent.name


def render_fixed_section(repo_root: Path) -> str:
    repo_root = repo_root.resolve()
    files, missing = fixed_cost_files(
        repo_root, claude_md=repo_root / "CLAUDE.md", claude_local_md=repo_root / "CLAUDE.local.md"
    )
    total_words = sum(word_count(p) for p in files)
    lines = ["## Fixed cost (always loaded)", "", "| File | Words | ~Tokens |", "|---|---|---|"]
    for p in files:
        w = word_count(p)
        lines.append(f"| `{p.relative_to(repo_root)}` | {w} | {to_tokens(w)} |")
    lines.append(f"| **Total fixed** | **{total_words}** | **≈{to_tokens(total_words)}** |")
    lines.append("")
    if missing:
        lines.append("### Broken includes (fixed-cost chain)")
        for referencing, target in missing:
            lines.append(f"- `{referencing.relative_to(repo_root)}` -> missing `{target}`")
        lines.append("")
    return "\n".join(lines)


def render_variable_section(repo_root: Path, only_skill: str = None) -> str:
    repo_root = repo_root.resolve()
    lines = ["## Variable cost (per skill invocation)", "", "| Skill | Words | ~Tokens |", "|---|---|---|"]
    rows = []
    for skill_md in iter_skill_files(repo_root / "skills"):
        name = skill_name(skill_md)
        if only_skill and name != only_skill:
            continue
        files, _ = resolve_includes(skill_md, repo_root)
        words = sum(word_count(p) for p in files)
        rows.append((name, words))
    for name, words in sorted(rows, key=lambda row: (-row[1], row[0])):
        lines.append(f"| {name} | {words} | ≈{to_tokens(words)} |")
    lines.append("")
    return "\n".join(lines)


def render_report(repo_root: Path, only_skill: str = None) -> str:
    sections = []
    if only_skill is None:
        sections.append(render_fixed_section(repo_root))
    sections.append(render_variable_section(repo_root, only_skill=only_skill))
    return "\n".join(sections) + "\n"


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixed-only", action="store_true", help="Print only the fixed-cost breakdown")
    parser.add_argument("--skill", help="Print only this skill's variable cost (its directory name, e.g. 'ship')")
    args = parser.parse_args(argv)

    if args.fixed_only:
        print(render_fixed_section(REPO_ROOT))
    else:
        print(render_report(REPO_ROOT, only_skill=args.skill))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
