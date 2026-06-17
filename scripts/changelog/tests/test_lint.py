import os
import tempfile
import textwrap
import unittest

from changelog.lint import lint


class TestLintBackwardCompat(unittest.TestCase):
    """Existing [user] / [user-none] / [non-user] behaviour must be preserved."""

    def _tmp(self, content: str) -> str:
        f = tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False, encoding='utf-8')
        f.write(textwrap.dedent(content))
        f.close()
        return f.name

    def tearDown(self):
        pass  # files cleaned up per-test

    def test_user_bullet_passes(self):
        path = self._tmp("""\
            ## [1.0.0] — 2026-01-01
            - [user] Something visible to users.
        """)
        try:
            self.assertEqual(lint(path, '0.0.0'), [])
        finally:
            os.unlink(path)

    def test_user_none_passes(self):
        path = self._tmp("""\
            ## [1.0.0] — 2026-01-01
            - [user-none]
        """)
        try:
            self.assertEqual(lint(path, '0.0.0'), [])
        finally:
            os.unlink(path)

    def test_user_with_non_user_passes(self):
        path = self._tmp("""\
            ## [1.0.0] — 2026-01-01
            - [user] Something visible.
            - [non-user] Internal detail.
        """)
        try:
            self.assertEqual(lint(path, '0.0.0'), [])
        finally:
            os.unlink(path)

    def test_untagged_entry_fails(self):
        path = self._tmp("""\
            ## [1.0.0] — 2026-01-01
            - Some bullet without any tag.
        """)
        try:
            errors = lint(path, '0.0.0')
            self.assertTrue(len(errors) > 0, 'Expected lint failure for untagged entry')
        finally:
            os.unlink(path)

    def test_non_user_alone_fails(self):
        """[non-user] is supplementary; it does not classify an entry on its own."""
        path = self._tmp("""\
            ## [1.0.0] — 2026-01-01
            - [non-user] Only a developer detail, no classification.
        """)
        try:
            errors = lint(path, '0.0.0')
            self.assertTrue(len(errors) > 0, 'Expected lint failure: [non-user] alone is not a classification')
        finally:
            os.unlink(path)

    def test_old_entries_not_checked(self):
        path = self._tmp("""\
            ## [1.0.0] — 2026-01-01
            - [user] New feature.

            ## [0.9.0] — 2025-12-01
            - No tag here — but this is old.
        """)
        try:
            self.assertEqual(lint(path, '0.9.0'), [])
        finally:
            os.unlink(path)

    def test_multiple_new_entries_all_must_be_tagged(self):
        path = self._tmp("""\
            ## [1.1.0] — 2026-02-01
            - [user] Feature.

            ## [1.0.0] — 2026-01-01
            - No tag here — new and should fail.
        """)
        try:
            errors = lint(path, '0.9.0')
            self.assertTrue(len(errors) > 0, 'Expected lint failure for the untagged 1.0.0 entry')
        finally:
            os.unlink(path)


class TestLintNewTags(unittest.TestCase):
    """New tags [app], [meta], [ci] must be accepted as valid classifications."""

    def _tmp(self, content: str) -> str:
        f = tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False, encoding='utf-8')
        f.write(textwrap.dedent(content))
        f.close()
        return f.name

    def test_app_bullet_passes(self):
        path = self._tmp("""\
            ## [1.0.0] — 2026-01-01
            - [app] Refactored persistence layer; no user-visible change.
        """)
        try:
            self.assertEqual(lint(path, '0.0.0'), [])
        finally:
            os.unlink(path)

    def test_meta_bullet_passes(self):
        path = self._tmp("""\
            ## [1.0.0] — 2026-01-01
            - [meta] Updated describe-feature skill.
        """)
        try:
            self.assertEqual(lint(path, '0.0.0'), [])
        finally:
            os.unlink(path)

    def test_ci_bullet_passes(self):
        path = self._tmp("""\
            ## [1.0.0] — 2026-01-01
            - [ci] Fixed CHANGELOG lint step.
        """)
        try:
            self.assertEqual(lint(path, '0.0.0'), [])
        finally:
            os.unlink(path)

    def test_app_with_non_user_passes(self):
        path = self._tmp("""\
            ## [1.0.0] — 2026-01-01
            - [app] Migrated to new DB schema.
            - [non-user] Migration runs on first launch.
        """)
        try:
            self.assertEqual(lint(path, '0.0.0'), [])
        finally:
            os.unlink(path)

    def test_mixed_meta_and_ci_passes(self):
        path = self._tmp("""\
            ## [1.0.0] — 2026-01-01
            - [meta] New plan skill.
            - [ci] Added matrix build.
        """)
        try:
            self.assertEqual(lint(path, '0.0.0'), [])
        finally:
            os.unlink(path)


class TestLintUnknownTags(unittest.TestCase):
    """Any [xxx] tag not in the known set must cause a lint failure."""

    def _tmp(self, content: str) -> str:
        f = tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False, encoding='utf-8')
        f.write(textwrap.dedent(content))
        f.close()
        return f.name

    def test_unknown_tag_fails(self):
        path = self._tmp("""\
            ## [1.0.0] — 2026-01-01
            - [foo] Unknown tag.
        """)
        try:
            errors = lint(path, '0.0.0')
            self.assertTrue(
                any('foo' in e for e in errors),
                f'Expected error mentioning unknown tag [foo]; got: {errors}',
            )
        finally:
            os.unlink(path)

    def test_unknown_tag_with_valid_classification_still_fails(self):
        """Even if the entry is classified, an unknown tag on any bullet is an error."""
        path = self._tmp("""\
            ## [1.0.0] — 2026-01-01
            - [user] Visible change.
            - [typo] Developer note with a misspelled tag.
        """)
        try:
            errors = lint(path, '0.0.0')
            self.assertTrue(
                any('typo' in e for e in errors),
                f'Expected error mentioning unknown tag [typo]; got: {errors}',
            )
        finally:
            os.unlink(path)
