import os
import tempfile
import textwrap
import unittest

from changelog.release_notes import _format, _parse_changelog


def _tmp(content: str) -> str:
    f = tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False, encoding='utf-8')
    f.write(textwrap.dedent(content))
    f.close()
    return f.name


class TestParseChangelog(unittest.TestCase):

    def test_user_bullet_extracted_and_tag_stripped(self):
        path = _tmp("""\
            ## [1.0.0] — 2026-01-01
            - [user] Button label improved.
            - [non-user] internal detail, not for users.
        """)
        try:
            self.assertEqual(_parse_changelog(path, '0.0.0'), ['Button label improved.'])
        finally:
            os.unlink(path)

    def test_user_none_suppresses_entire_entry(self):
        path = _tmp("""\
            ## [1.0.0] — 2026-01-01
            - [user-none]
        """)
        try:
            self.assertEqual(_parse_changelog(path, '0.0.0'), [])
        finally:
            os.unlink(path)

    def test_entry_with_no_user_bullets_and_no_sentinel_is_skipped(self):
        path = _tmp("""\
            ## [1.0.0] — 2026-01-01
            - [ci] Internal-only change.
        """)
        try:
            self.assertEqual(_parse_changelog(path, '0.0.0'), [])
        finally:
            os.unlink(path)

    def test_only_versions_newer_than_last_are_included(self):
        path = _tmp("""\
            ## [1.1.0] — 2026-02-01
            - [user] New thing.

            ## [1.0.0] — 2026-01-01
            - [user] Old thing (must be excluded).
        """)
        try:
            self.assertEqual(_parse_changelog(path, '1.0.0'), ['New thing.'])
        finally:
            os.unlink(path)

    # --- HAB-185: sealed ## [Unreleased] sections between numbered releases ---

    def test_sealed_unreleased_user_none_does_not_suppress_newer_entry(self):
        """A [user-none] sentinel sitting in a sealed Unreleased batch (sandwiched
        between two numbered releases) must not suppress the NEWER release's own
        real [user] bullets."""
        path = _tmp("""\
            ## [1.1.0] — 2026-02-01
            - [user] Real user-facing change that must survive.

            ## [Unreleased]
            - [user-none]

            ## [1.0.0] — 2026-01-01
            - [user] Old thing (must be excluded by version filter).
        """)
        try:
            self.assertEqual(_parse_changelog(path, '1.0.0'), ['Real user-facing change that must survive.'])
        finally:
            os.unlink(path)

    def test_sealed_unreleased_bullets_never_appear_in_output(self):
        path = _tmp("""\
            ## [1.1.0] — 2026-02-01
            - [user] Real user-facing change.

            ## [Unreleased]
            - [user] this must never surface — Unreleased is never user-facing output.

            ## [1.0.0] — 2026-01-01
            - [user] Old thing.
        """)
        try:
            self.assertEqual(_parse_changelog(path, '1.0.0'), ['Real user-facing change.'])
        finally:
            os.unlink(path)


class TestFormat(unittest.TestCase):

    def test_formats_as_bullet_list(self):
        self.assertEqual(_format(['First.', 'Second.']), '• First.\n• Second.')

    def test_empty_list_yields_fallback_text(self):
        self.assertEqual(_format([]), 'Bug fixes and improvements.')


if __name__ == '__main__':
    unittest.main()
