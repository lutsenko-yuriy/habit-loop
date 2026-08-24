from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from scripts.docs import context_cost


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


class ParseIncludesTests(unittest.TestCase):
    def test_standalone_at_line_is_an_include(self):
        text = "Some prose.\n\n@docs/ARCHITECTURE.md\n\nMore prose.\n"
        self.assertEqual(context_cost.parse_includes(text), ["docs/ARCHITECTURE.md"])

    def test_at_path_inside_backticks_is_not_an_include(self):
        text = "- `@docs/ARCHITECTURE.md` — code structure or dependencies changed\n"
        self.assertEqual(context_cost.parse_includes(text), [])

    def test_at_path_with_surrounding_text_is_still_an_include_if_not_backticked(self):
        # Mirrors AGENTS.md's real "Details: @docs/VERSIONING.md" line, which
        # does expand despite not being a standalone line — see HAB-220.
        text = "Details: @docs/VERSIONING.md\n"
        self.assertEqual(context_cost.parse_includes(text), ["docs/VERSIONING.md"])

    def test_multiple_includes_preserve_order(self):
        text = "@skills/shared/a.md\nprose\n@skills/shared/b.md\n"
        self.assertEqual(
            context_cost.parse_includes(text), ["skills/shared/a.md", "skills/shared/b.md"]
        )

    def test_no_includes_returns_empty(self):
        self.assertEqual(context_cost.parse_includes("just prose\n"), [])


class ResolveIncludesTests(unittest.TestCase):
    def test_resolves_transitive_chain_in_order(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write(root / "a.md", "@b.md\n")
            write(root / "b.md", "@c.md\n")
            write(root / "c.md", "leaf content\n")

            files, missing = context_cost.resolve_includes(root / "a.md", root)

            self.assertEqual([f.name for f in files], ["a.md", "b.md", "c.md"])
            self.assertEqual(missing, [])

    def test_shared_include_is_not_double_counted(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write(root / "a.md", "@shared.md\n")
            write(root / "b.md", "@shared.md\n@a.md\n")
            write(root / "shared.md", "shared content\n")

            files, _ = context_cost.resolve_includes(root / "b.md", root)

            self.assertEqual([f.name for f in files], ["b.md", "shared.md", "a.md"])

    def test_cycle_does_not_infinite_loop(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write(root / "a.md", "@b.md\n")
            write(root / "b.md", "@a.md\n")

            files, _ = context_cost.resolve_includes(root / "a.md", root)

            self.assertEqual([f.name for f in files], ["a.md", "b.md"])

    def test_missing_include_target_is_reported_not_raised(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write(root / "a.md", "@does-not-exist.md\n")

            files, missing = context_cost.resolve_includes(root / "a.md", root)

            self.assertEqual([f.name for f in files], ["a.md"])
            self.assertEqual(len(missing), 1)
            referencing, target = missing[0]
            self.assertEqual(referencing.name, "a.md")
            self.assertEqual(target, "does-not-exist.md")

    def test_backtick_wrapped_reference_is_not_followed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write(root / "a.md", "- `@b.md` — mentioned as prose, not included\n")
            write(root / "b.md", "leaf content\n")

            files, missing = context_cost.resolve_includes(root / "a.md", root)

            self.assertEqual([f.name for f in files], ["a.md"])
            self.assertEqual(missing, [])

    def test_max_depth_caps_recursion(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write(root / "a.md", "@b.md\n")
            write(root / "b.md", "@c.md\n")
            write(root / "c.md", "leaf content\n")

            files, _ = context_cost.resolve_includes(root / "a.md", root, max_depth=1)

            # a.md (depth 0) -> b.md (depth 1) reached; b.md's own @c.md
            # (would be depth 2) is not followed.
            self.assertEqual([f.name for f in files], ["a.md", "b.md"])


class WordCountTests(unittest.TestCase):
    def test_counts_whitespace_separated_words(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "f.md"
            write(path, "one two three\nfour\n")
            self.assertEqual(context_cost.word_count(path), 4)

    def test_to_tokens_applies_ratio(self):
        self.assertEqual(context_cost.to_tokens(100), round(100 * context_cost.TOKENS_PER_WORD))


class FixedCostFilesTests(unittest.TestCase):
    def test_includes_claude_local_md_even_though_not_at_included(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write(root / "CLAUDE.md", "@AGENTS.md\n")
            write(root / "AGENTS.md", "root docs\n")
            write(root / "CLAUDE.local.md", "local machine notes\n")

            files, _ = context_cost.fixed_cost_files(
                root, claude_md=root / "CLAUDE.md", claude_local_md=root / "CLAUDE.local.md"
            )

            names = {f.name for f in files}
            self.assertEqual(names, {"CLAUDE.md", "AGENTS.md", "CLAUDE.local.md"})

    def test_hop_3_includes_are_not_expanded(self):
        # Mirrors the real shape: CLAUDE.md -> AGENTS.md (hop 1) -> FEATURE.md
        # (hop 2) -> decision-guidelines.md (hop 3, must NOT be reached).
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write(root / "CLAUDE.md", "@AGENTS.md\n")
            write(root / "AGENTS.md", "@FEATURE.md\n")
            write(root / "FEATURE.md", "@decision-guidelines.md\n")
            write(root / "decision-guidelines.md", "guideline content\n")
            write(root / "CLAUDE.local.md", "local\n")

            files, _ = context_cost.fixed_cost_files(
                root, claude_md=root / "CLAUDE.md", claude_local_md=root / "CLAUDE.local.md"
            )

            names = {f.name for f in files}
            self.assertEqual(names, {"CLAUDE.md", "AGENTS.md", "FEATURE.md", "CLAUDE.local.md"})
            self.assertNotIn("decision-guidelines.md", names)

    def test_missing_claude_local_md_is_tolerated(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write(root / "CLAUDE.md", "@AGENTS.md\n")
            write(root / "AGENTS.md", "root docs\n")

            files, missing = context_cost.fixed_cost_files(
                root,
                claude_md=root / "CLAUDE.md",
                claude_local_md=root / "CLAUDE.local.md.missing",
            )

            self.assertEqual([f.name for f in files], ["CLAUDE.md", "AGENTS.md"])
            self.assertEqual(missing, [])


class SkillCostTests(unittest.TestCase):
    def test_iter_skill_files_finds_every_skill_md(self):
        with tempfile.TemporaryDirectory() as tmp:
            skills_dir = Path(tmp) / "skills"
            write(skills_dir / "build" / "implement" / "SKILL.md", "content\n")
            write(skills_dir / "manage" / "ship" / "SKILL.md", "content\n")

            found = context_cost.iter_skill_files(skills_dir)

            self.assertEqual(len(found), 2)


class RenderReportTests(unittest.TestCase):
    def test_render_report_includes_fixed_and_variable_sections(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write(root / "CLAUDE.md", "@AGENTS.md\n")
            write(root / "AGENTS.md", "one two three four five\n")
            write(root / "CLAUDE.local.md", "local\n")
            write(root / "skills" / "manage" / "ship" / "SKILL.md", "skill body words here\n")

            report = context_cost.render_report(root)

            self.assertIn("Fixed cost", report)
            self.assertIn("Variable cost", report)
            self.assertIn("AGENTS.md", report)
            self.assertIn("ship", report)


if __name__ == "__main__":
    unittest.main()
