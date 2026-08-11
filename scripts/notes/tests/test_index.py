import tempfile
import unittest
from pathlib import Path

from scripts.notes import index


def write(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")


class ParseNoteTests(unittest.TestCase):
    def test_no_frontmatter_is_missing_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            note = Path(tmp) / "HAB-1.md"
            write(note, "# HAB-1: Title\n\nBody.\n")
            has_key, bookmarks = index.parse_note(note)
            self.assertFalse(has_key)
            self.assertEqual(bookmarks, [])

    def test_frontmatter_without_bookmarks_key_is_missing_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            note = Path(tmp) / "HAB-1.md"
            write(note, "---\nother: value\n---\n\n# HAB-1: Title\n")
            has_key, bookmarks = index.parse_note(note)
            self.assertFalse(has_key)

    def test_explicit_empty_list_is_present_but_empty(self):
        with tempfile.TemporaryDirectory() as tmp:
            note = Path(tmp) / "HAB-1.md"
            write(note, "---\nbookmarks: []\n---\n\n# HAB-1: Title\n")
            has_key, bookmarks = index.parse_note(note)
            self.assertTrue(has_key)
            self.assertEqual(bookmarks, [])

    def test_populated_list_is_parsed(self):
        with tempfile.TemporaryDirectory() as tmp:
            note = Path(tmp) / "HAB-1.md"
            write(note, "---\nbookmarks: [ci-flakiness, scope-creep]\n---\n\n# HAB-1: Title\n")
            has_key, bookmarks = index.parse_note(note)
            self.assertTrue(has_key)
            self.assertEqual(bookmarks, ["ci-flakiness", "scope-creep"])

    def test_quoted_items_are_unquoted(self):
        with tempfile.TemporaryDirectory() as tmp:
            note = Path(tmp) / "HAB-1.md"
            write(note, "---\nbookmarks: ['ci-flakiness', \"scope-creep\"]\n---\n\n# HAB-1: Title\n")
            has_key, bookmarks = index.parse_note(note)
            self.assertEqual(bookmarks, ["ci-flakiness", "scope-creep"])


class LoadVocabularyTests(unittest.TestCase):
    def test_missing_file_yields_empty_vocabulary(self):
        self.assertEqual(index.load_vocabulary(Path("/nonexistent/BOOKMARKS.md")), set())

    def test_reads_bookmark_names_from_table_rows(self):
        with tempfile.TemporaryDirectory() as tmp:
            vocab_file = Path(tmp) / "BOOKMARKS.md"
            write(
                vocab_file,
                "# Bookmarks\n\n"
                "| Bookmark | Meaning |\n"
                "|---|---|\n"
                "| `ci-flakiness` | Intermittent CI failures |\n"
                "| `scope-creep` | Ticket grew mid-flight |\n",
            )
            self.assertEqual(index.load_vocabulary(vocab_file), {"ci-flakiness", "scope-creep"})


class CheckTests(unittest.TestCase):
    def _setup_corpus(self, tmp, notes):
        notes_dir = Path(tmp) / "notes"
        notes_dir.mkdir()
        for name, content in notes.items():
            write(notes_dir / name, content)
        vocab_file = notes_dir / "BOOKMARKS.md"
        write(
            vocab_file,
            "# Bookmarks\n\n| Bookmark | Meaning |\n|---|---|\n| `ci-flakiness` | Intermittent CI failures |\n",
        )
        return notes_dir, vocab_file

    def test_clean_tree_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            notes_dir, vocab_file = self._setup_corpus(
                tmp, {"HAB-1.md": "---\nbookmarks: [ci-flakiness]\n---\n\n# HAB-1: T\n"}
            )
            index_file = notes_dir / "INDEX.md"
            index.write_index(notes_dir, vocab_file, index_file)
            errors = index.check(notes_dir, vocab_file, index_file)
            self.assertEqual(errors, [])

    def test_missing_bookmarks_key_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            notes_dir, vocab_file = self._setup_corpus(tmp, {"HAB-1.md": "# HAB-1: T\n\nBody.\n"})
            index_file = notes_dir / "INDEX.md"
            index.write_index(notes_dir, vocab_file, index_file)
            errors = index.check(notes_dir, vocab_file, index_file)
            self.assertTrue(any("missing" in e and "HAB-1.md" in e for e in errors))

    def test_explicit_empty_list_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            notes_dir, vocab_file = self._setup_corpus(tmp, {"HAB-1.md": "---\nbookmarks: []\n---\n\n# HAB-1: T\n"})
            index_file = notes_dir / "INDEX.md"
            index.write_index(notes_dir, vocab_file, index_file)
            errors = index.check(notes_dir, vocab_file, index_file)
            self.assertEqual(errors, [])

    def test_unknown_bookmark_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            notes_dir, vocab_file = self._setup_corpus(
                tmp, {"HAB-1.md": "---\nbookmarks: [not-in-vocabulary]\n---\n\n# HAB-1: T\n"}
            )
            index_file = notes_dir / "INDEX.md"
            index.write_index(notes_dir, vocab_file, index_file)
            errors = index.check(notes_dir, vocab_file, index_file)
            self.assertTrue(any("unknown bookmark" in e and "not-in-vocabulary" in e for e in errors))

    def test_stale_index_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            notes_dir, vocab_file = self._setup_corpus(
                tmp, {"HAB-1.md": "---\nbookmarks: [ci-flakiness]\n---\n\n# HAB-1: T\n"}
            )
            index_file = notes_dir / "INDEX.md"
            write(index_file, "stale content\n")
            errors = index.check(notes_dir, vocab_file, index_file)
            self.assertTrue(any("stale" in e for e in errors))

    def test_template_and_generated_files_are_excluded_from_scan(self):
        with tempfile.TemporaryDirectory() as tmp:
            notes_dir, vocab_file = self._setup_corpus(
                tmp, {"HAB-1.md": "---\nbookmarks: [ci-flakiness]\n---\n\n# HAB-1: T\n"}
            )
            write(notes_dir / "TEMPLATE.md", "---\nbookmarks: []\n---\n\n# HAB-XX: <title>\n")
            index_file = notes_dir / "INDEX.md"
            index.write_index(notes_dir, vocab_file, index_file)
            errors = index.check(notes_dir, vocab_file, index_file)
            self.assertEqual(errors, [])


class GenerateIndexTests(unittest.TestCase):
    def test_regeneration_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            notes_dir = Path(tmp) / "notes"
            notes_dir.mkdir()
            write(notes_dir / "HAB-1.md", "---\nbookmarks: [ci-flakiness]\n---\n\n# HAB-1: T\n")
            vocab_file = notes_dir / "BOOKMARKS.md"
            write(vocab_file, "# Bookmarks\n\n| Bookmark | Meaning |\n|---|---|\n| `ci-flakiness` | x |\n")
            first = index.render_index(notes_dir, vocab_file)
            second = index.render_index(notes_dir, vocab_file)
            self.assertEqual(first, second)

    def test_notes_grouped_under_their_bookmark(self):
        with tempfile.TemporaryDirectory() as tmp:
            notes_dir = Path(tmp) / "notes"
            notes_dir.mkdir()
            write(notes_dir / "HAB-1.md", "---\nbookmarks: [ci-flakiness]\n---\n\n# HAB-1: One\n")
            write(notes_dir / "HAB-2.md", "---\nbookmarks: []\n---\n\n# HAB-2: Two\n")
            vocab_file = notes_dir / "BOOKMARKS.md"
            write(vocab_file, "# Bookmarks\n\n| Bookmark | Meaning |\n|---|---|\n| `ci-flakiness` | x |\n")
            rendered = index.render_index(notes_dir, vocab_file)
            self.assertIn("HAB-1.md", rendered)
            self.assertIn("ci-flakiness", rendered)
            self.assertIn("HAB-2.md", rendered)


class ApplyBookmarksTests(unittest.TestCase):
    def test_inserts_frontmatter_without_touching_body(self):
        with tempfile.TemporaryDirectory() as tmp:
            notes_dir = Path(tmp) / "notes"
            notes_dir.mkdir()
            note = notes_dir / "HAB-1.md"
            write(note, "# HAB-1: Title\n\nOriginal body text.\n")
            index.apply_bookmarks(notes_dir, {"HAB-1.md": ["ci-flakiness"]})
            content = note.read_text(encoding="utf-8")
            self.assertTrue(content.startswith("---\nbookmarks: [ci-flakiness]\n---\n"))
            self.assertIn("Original body text.", content)

    def test_does_not_overwrite_existing_frontmatter(self):
        with tempfile.TemporaryDirectory() as tmp:
            notes_dir = Path(tmp) / "notes"
            notes_dir.mkdir()
            note = notes_dir / "HAB-1.md"
            write(note, "---\nbookmarks: [scope-creep]\n---\n\n# HAB-1: Title\n")
            index.apply_bookmarks(notes_dir, {"HAB-1.md": ["ci-flakiness"]})
            content = note.read_text(encoding="utf-8")
            self.assertIn("bookmarks: [scope-creep]", content)


if __name__ == "__main__":
    unittest.main()
