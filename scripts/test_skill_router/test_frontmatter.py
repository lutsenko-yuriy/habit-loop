import unittest
from unittest.mock import patch

from skill_router.frontmatter import _normalize_model_name, read_frontmatter, lookup_lmstudio_model
from skill_router.constants import MAX_TOOL_TURNS
from .fixtures import (
    TIERS_MD_WITH_LMSTUDIO,
    SKILL_CONTENT_PLAIN,
    SKILL_CONTENT_NEEDS_MCP,
    SKILL_CONTENT_WITH_CONTEXT,
    SKILL_CONTENT_WITH_TOOLS,
    SKILL_CONTENT_NO_FM,
)


class TestNormalizeModelName(unittest.TestCase):

    def test_strips_parenthetical_quantization(self):
        self.assertEqual(_normalize_model_name("qwen/qwen3-8b (MLX, 4-bit)"), "qwen/qwen3-8b")

    def test_strips_after_first_space(self):
        self.assertEqual(_normalize_model_name("mistralai/devstral-small 4bit"), "mistralai/devstral-small")

    def test_lowercases(self):
        self.assertEqual(_normalize_model_name("Qwen/Qwen3-8B"), "qwen/qwen3-8b")

    def test_plain_name_unchanged(self):
        self.assertEqual(_normalize_model_name("qwen/qwen3-8b"), "qwen/qwen3-8b")

    def test_strips_leading_trailing_whitespace(self):
        self.assertEqual(_normalize_model_name("  qwen/qwen3-8b  "), "qwen/qwen3-8b")


class TestReadFrontmatter(unittest.TestCase):

    def _parse(self, content):
        with patch("pathlib.Path.read_text", return_value=content):
            return read_frontmatter("fake/SKILL.md")

    def test_parses_effort_and_reasoning(self):
        effort, reasoning, _, _, _, _, _ = self._parse(SKILL_CONTENT_PLAIN)
        self.assertEqual(effort, "RAPID")
        self.assertEqual(reasoning, "MECHANICAL")

    def test_needs_session_tools_false_by_default(self):
        _, _, needs_session_tools, _, _, _, _ = self._parse(SKILL_CONTENT_PLAIN)
        self.assertFalse(needs_session_tools)

    def test_needs_session_tools_true_when_set(self):
        _, _, needs_session_tools, _, _, _, _ = self._parse(SKILL_CONTENT_NEEDS_MCP)
        self.assertTrue(needs_session_tools)

    def test_context_none_by_default(self):
        _, _, _, context, _, _, _ = self._parse(SKILL_CONTENT_PLAIN)
        self.assertIsNone(context)

    def test_context_parsed_when_set(self):
        _, _, _, context, _, _, _ = self._parse(SKILL_CONTENT_WITH_CONTEXT)
        self.assertEqual(context, "linear")

    def test_tools_empty_by_default(self):
        _, _, _, _, tools, _, _ = self._parse(SKILL_CONTENT_PLAIN)
        self.assertEqual(tools, [])

    def test_tools_parsed_when_set(self):
        _, _, _, _, tools, _, _ = self._parse(SKILL_CONTENT_WITH_TOOLS)
        self.assertEqual(tools, ["linear", "github"])

    def test_max_turns_defaults_to_constant(self):
        _, _, _, _, _, max_turns, _ = self._parse(SKILL_CONTENT_PLAIN)
        self.assertEqual(max_turns, MAX_TOOL_TURNS)

    def test_max_turns_parsed_when_set(self):
        content = "---\neffort: RAPID\nreasoning: MECHANICAL\nmax_turns: 60\n---\nDo the thing.\n"
        _, _, _, _, _, max_turns, _ = self._parse(content)
        self.assertEqual(max_turns, 60)

    def test_body_excludes_frontmatter(self):
        _, _, _, _, _, _, body = self._parse(SKILL_CONTENT_PLAIN)
        self.assertEqual(body, "Do the thing.\n")

    def test_no_frontmatter_returns_none_fields(self):
        effort, reasoning, needs_session_tools, context, tools, max_turns, body = self._parse(SKILL_CONTENT_NO_FM)
        self.assertIsNone(effort)
        self.assertIsNone(reasoning)
        self.assertFalse(needs_session_tools)
        self.assertIsNone(context)
        self.assertEqual(tools, [])
        self.assertEqual(max_turns, MAX_TOOL_TURNS)
        self.assertEqual(body, SKILL_CONTENT_NO_FM)


class TestLookupLmstudioModel(unittest.TestCase):

    def _lookup(self, effort, reasoning, tiers_content=TIERS_MD_WITH_LMSTUDIO):
        with patch("pathlib.Path.read_text", return_value=tiers_content):
            return lookup_lmstudio_model(effort, reasoning)

    def test_returns_model_for_lm_studio_alias(self):
        model = self._lookup("RAPID", "MECHANICAL")
        self.assertEqual(model, "qwen/qwen3-8b (MLX, 4-bit)")

    def test_returns_none_for_non_lm_studio_alias(self):
        model = self._lookup("THOROUGH", "ARCHITECTURAL")
        self.assertIsNone(model)

    def test_returns_none_for_missing_combination(self):
        model = self._lookup("FOCUSED", "TACTICAL")
        self.assertIsNone(model)

    def test_returns_none_when_file_missing(self):
        with patch("pathlib.Path.read_text", side_effect=FileNotFoundError):
            model = lookup_lmstudio_model("RAPID", "MECHANICAL")
        self.assertIsNone(model)

    def test_returns_none_when_section_missing(self):
        model = self._lookup("RAPID", "MECHANICAL", tiers_content="no active mapping here")
        self.assertIsNone(model)


if __name__ == "__main__":
    unittest.main()
