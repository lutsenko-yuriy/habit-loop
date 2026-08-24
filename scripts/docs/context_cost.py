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

Two caveats on that number, surfaced during PR review (HAB-220):
- `CLAUDE.local.md` is gitignored and per-machine — its word count (and
  therefore the fixed-cost total) is **not reproducible across machines or
  CI**. The qualitative classification (loaded every session vs. loaded
  per-skill) still holds everywhere; only the exact digit is local.
- The depth-2 cap is this script's best available model, verified against
  one real rendered session, but a competing explanation (`@path` resolved
  relative to its *containing* file rather than cut off by hop count) fits
  every observation in this repo equally, since every hop-2 file's own
  `@`-include happens to be repo-root-relative already. Re-verify against a
  hop-2 file that names a path relative to itself before trusting this
  script across a differently-shaped include graph.

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
from collections import deque
from pathlib import Path
from typing import Dict, List, Optional, Tuple

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

FENCED_BLOCK_RE = re.compile(r"```.*?```", re.DOTALL)
BACKTICK_SPAN_RE = re.compile(r"`[^`\n]*`")
# (?<!\w) excludes an email-like "me@example.md" or a URL fragment ending in a
# word character right before the "@" — a real include always follows either
# start-of-text or whitespace/punctuation, never a word character (HAB-220 audit).
AT_MD_RE = re.compile(r"(?<!\w)@(\S+\.md)")

Missing = Tuple[Path, str]  # (file that referenced it, the missing relative path)


def parse_includes(text: str) -> List[str]:
    """Repo-relative paths named by non-backtick-wrapped `@path.md` references
    in `text`, in the order they appear. Fenced ``` code blocks are stripped
    from the whole text first (an example inside one is not a real include),
    then backtick-wrapped occurrences are stripped per remaining line (an
    inline-code mention is not a real include either)."""
    unfenced = FENCED_BLOCK_RE.sub("", text)
    includes = []
    for line in unfenced.splitlines():
        cleaned = BACKTICK_SPAN_RE.sub("", line)
        includes.extend(match.group(1) for match in AT_MD_RE.finditer(cleaned))
    return includes


def resolve_includes(
    start: Path, repo_root: Path, max_depth: Optional[int] = None
) -> Tuple[List[Path], List[Missing]]:
    """Transitively resolve `start`'s `@`-include chain via breadth-first
    search, so a file's recorded depth is always its *shortest* distance from
    `start` regardless of which parent happens to be processed first.

    A depth-first, "seen once ever" visit order — the original
    implementation — under-counts: a file first reached through a long path
    gets marked done at that depth, and a later, shorter path to the same
    file is then skipped even though it would have cleared `max_depth` (HAB-220
    review). BFS avoids this because every node is enqueued at most once, the
    first time it's discovered, and BFS discovers nodes in non-decreasing
    depth order — so that first discovery is always the shortest one.

    `max_depth` caps how many hops from `start` are followed (`start` itself
    is depth 0); `None` means unlimited. Use this to model the real,
    depth-2-from-`CLAUDE.md` cap described in the module docstring for fixed
    cost, while leaving skill variable-cost resolution uncapped.

    Returns (files, missing): `files` is every existing file reached,
    de-duplicated and in order of first discovery (`start` first); `missing`
    is every include line whose target file does not exist, reported rather
    than raised so one broken link doesn't stop the whole measurement.
    """
    start_resolved = start.resolve()
    depth_of: Dict[Path, int] = {start_resolved: 0}
    files: List[Path] = []
    missing: List[Missing] = []
    queue = deque([(start_resolved, 0)])

    while queue:
        path, depth = queue.popleft()
        if not path.exists():
            continue
        files.append(path)
        if max_depth is not None and depth >= max_depth:
            continue
        text = path.read_text(encoding="utf-8")
        for rel in parse_includes(text):
            target = (repo_root / rel).resolve()
            if not target.exists():
                missing.append((path, rel))
                continue
            if target not in depth_of:
                depth_of[target] = depth + 1
                queue.append((target, depth + 1))

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


def _display_path(path: Path, repo_root: Path) -> str:
    """`path` relative to `repo_root` for display, falling back to the
    absolute path if it genuinely lies outside `repo_root` (e.g. a `@../x.md`
    escape or an out-of-repo symlink target) — a formatting concern only,
    never worth crashing the whole report over (HAB-220 audit)."""
    try:
        return str(path.relative_to(repo_root))
    except ValueError:
        return str(path)


def _render_missing(missing: List[Missing], repo_root: Path, heading: str) -> List[str]:
    if not missing:
        return []
    lines = [heading]
    for referencing, target in missing:
        lines.append(f"- `{_display_path(referencing, repo_root)}` -> missing `{target}`")
    lines.append("")
    return lines


def render_fixed_section(repo_root: Path) -> str:
    repo_root = repo_root.resolve()
    files, missing = fixed_cost_files(
        repo_root, claude_md=repo_root / "CLAUDE.md", claude_local_md=repo_root / "CLAUDE.local.md"
    )
    total_words = sum(word_count(p) for p in files)
    lines = ["## Fixed cost (always loaded)", "", "| File | Words | ~Tokens |", "|---|---|---|"]
    for p in files:
        w = word_count(p)
        lines.append(f"| `{_display_path(p, repo_root)}` | {w} | {to_tokens(w)} |")
    lines.append(f"| **Total fixed** | **{total_words}** | **≈{to_tokens(total_words)}** |")
    lines.append("")
    lines.extend(_render_missing(missing, repo_root, "### Broken includes (fixed-cost chain)"))
    return "\n".join(lines)


def render_variable_section(repo_root: Path, only_skill: str = None) -> str:
    repo_root = repo_root.resolve()
    lines = ["## Variable cost (per skill invocation)", "", "| Skill | Words | ~Tokens |", "|---|---|---|"]
    rows = []
    all_missing: List[Missing] = []
    for skill_md in iter_skill_files(repo_root / "skills"):
        name = skill_name(skill_md)
        if only_skill and name != only_skill:
            continue
        files, missing = resolve_includes(skill_md, repo_root)
        words = sum(word_count(p) for p in files)
        rows.append((name, words))
        all_missing.extend(missing)
    for name, words in sorted(rows, key=lambda row: (-row[1], row[0])):
        lines.append(f"| {name} | {words} | ≈{to_tokens(words)} |")
    lines.append("")
    lines.extend(_render_missing(all_missing, repo_root, "### Broken includes (skills)"))
    return "\n".join(lines)


def render_report(repo_root: Path, only_skill: str = None) -> str:
    sections = []
    if only_skill is None:
        sections.append(render_fixed_section(repo_root))
    sections.append(render_variable_section(repo_root, only_skill=only_skill))
    return "\n".join(sections) + "\n"


def main(argv: List[str], repo_root: Path = REPO_ROOT) -> int:
    parser = argparse.ArgumentParser(
        description="Measure fixed (always-loaded) vs. variable (per-skill) `@`-include token cost. "
        "See this file's module docstring for the full model and its caveats."
    )
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--fixed-only", action="store_true", help="Print only the fixed-cost breakdown")
    group.add_argument("--skill", help="Print only this skill's variable cost (its directory name, e.g. 'ship')")
    args = parser.parse_args(argv)

    if args.skill is not None:
        known = {skill_name(p) for p in iter_skill_files(repo_root / "skills")}
        if args.skill not in known:
            print(f"Unknown skill: {args.skill!r} (no skills/**/{args.skill}/SKILL.md found)", file=sys.stderr)
            return 2
        print(render_report(repo_root, only_skill=args.skill))
    elif args.fixed_only:
        print(render_fixed_section(repo_root))
    else:
        print(render_report(repo_root))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
