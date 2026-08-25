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

    # --- HAB-247: [trivial] delayed release-notes inclusion ---

    def test_trivial_in_sealed_unreleased_batch_is_emitted_once_the_sealing_release_is_newer(self):
        path = _tmp("""\
            ## [1.1.0] — 2026-02-01
            - [user] Real feature.

            ## [Unreleased]
            - [trivial] Copy tweak that rode along with 1.1.0.

            ## [1.0.0] — 2026-01-01
            - [user] Old thing.
        """)
        try:
            self.assertEqual(
                _parse_changelog(path, '1.0.0'),
                ['Real feature.', 'Copy tweak that rode along with 1.1.0.'],
            )
        finally:
            os.unlink(path)

    def test_trivial_in_sealed_batch_not_re_emitted_once_sealing_release_is_published(self):
        """Once P >= the sealing release's version, that batch's [trivial] bullets
        must never be emitted again — the V > P filter must apply to sealed
        Unreleased batches exactly as it does to numbered entries."""
        path = _tmp("""\
            ## [1.1.0] — 2026-02-01
            - [user] Real feature.

            ## [Unreleased]
            - [trivial] Copy tweak that already shipped with 1.1.0.

            ## [1.0.0] — 2026-01-01
            - [user] Old thing.
        """)
        try:
            self.assertEqual(_parse_changelog(path, '1.1.0'), [])
        finally:
            os.unlink(path)

    def test_trivial_in_open_unreleased_batch_never_emitted(self):
        """The open batch at the top of the file (no numbered heading above it)
        has no sealing release yet — its [trivial] bullets must not surface,
        even though the older numbered release below it still contributes its
        own [user] bullets as normal."""
        path = _tmp("""\
            ## [Unreleased]
            - [trivial] Not shipped in any build yet.

            ## [1.0.0] — 2026-01-01
            - [user] Old thing.
        """)
        try:
            self.assertEqual(_parse_changelog(path, '0.0.0'), ['Old thing.'])
        finally:
            os.unlink(path)

    def test_user_none_inside_sealed_batch_does_not_suppress_its_trivial_bullets(self):
        path = _tmp("""\
            ## [1.1.0] — 2026-02-01
            - [user] Real feature.

            ## [Unreleased]
            - [user-none]
            - [trivial] Copy tweak — must still surface despite the sentinel.

            ## [1.0.0] — 2026-01-01
            - [user] Old thing.
        """)
        try:
            self.assertEqual(
                _parse_changelog(path, '1.0.0'),
                ['Real feature.', 'Copy tweak — must still surface despite the sentinel.'],
            )
        finally:
            os.unlink(path)

    def test_trivial_numbered_entry_emitted_with_tag_stripped(self):
        """The --release-now path: a [trivial]-only entry under its own numbered
        heading is treated like any other newer entry."""
        path = _tmp("""\
            ## [1.0.1] — 2026-01-02
            - [trivial] Explicit release of a copy tweak.
        """)
        try:
            self.assertEqual(_parse_changelog(path, '1.0.0'), ['Explicit release of a copy tweak.'])
        finally:
            os.unlink(path)

    def test_trivial_concatenated_with_another_tag_is_not_extracted(self):
        """[audit finding] A concatenated multi-tag bullet like "[trivial][meta] ..."
        — the repo's actual house style for Unreleased bullets, e.g.
        docs/CHANGELOG.md's "[ci][meta] HAB-250: ..." — must not partially
        match _TRIVIAL_TAG and leak a malformed "[meta] ..." line into
        release notes. Multi-tag [trivial] extraction is explicitly out of
        scope (HAB-247 plan); the bullet must simply be excluded."""
        path = _tmp("""\
            ## [1.1.0] — 2026-02-01
            - [trivial][meta] Renamed the Start button.

            ## [1.0.0] — 2026-01-01
            - [user] Old thing.
        """)
        try:
            self.assertEqual(_parse_changelog(path, '1.0.0'), [])
        finally:
            os.unlink(path)

    def test_bare_trivial_sentinel_is_not_extracted(self):
        """[audit finding] A bare "- [trivial]" with no description must not
        produce an empty bullet in release notes."""
        path = _tmp("""\
            ## [1.1.0] — 2026-02-01
            - [trivial]

            ## [1.0.0] — 2026-01-01
            - [user] Old thing.
        """)
        try:
            self.assertEqual(_parse_changelog(path, '1.0.0'), [])
        finally:
            os.unlink(path)

    def test_sealed_batch_trivial_bullets_ordered_after_their_sealing_releases_user_bullets(self):
        path = _tmp("""\
            ## [1.1.0] — 2026-02-01
            - [user] Real feature.

            ## [Unreleased]
            - [trivial] Copy tweak.

            ## [1.0.0] — 2026-01-01
            - [user] Old thing.
        """)
        try:
            self.assertEqual(
                _parse_changelog(path, '0.0.0'),
                ['Real feature.', 'Copy tweak.', 'Old thing.'],
            )
        finally:
            os.unlink(path)


    # --- HAB-252: dead cleanup functions now wired in ---

    def test_user_bullet_stripped_of_ticket_and_pr_references(self):
        path = _tmp("""\
            ## [1.0.0] — 2026-01-01
            - [user] HAB-55: Button label improved (PR #92 merged).
        """)
        try:
            self.assertEqual(_parse_changelog(path, '0.0.0'), ['Button label improved.'])
        finally:
            os.unlink(path)

    def test_user_bullet_that_is_only_a_dev_status_line_is_dropped(self):
        path = _tmp("""\
            ## [1.0.0] — 2026-01-01
            - [user] 42 tests passing.
            - [user] Real change.
        """)
        try:
            self.assertEqual(_parse_changelog(path, '0.0.0'), ['Real change.'])
        finally:
            os.unlink(path)


class TestFormat(unittest.TestCase):

    def test_formats_as_bullet_list(self):
        self.assertEqual(_format(['First.', 'Second.']), '• First.\n• Second.')

    def test_empty_list_yields_fallback_text(self):
        self.assertEqual(_format([]), 'Bug fixes and improvements.')


if __name__ == '__main__':
    unittest.main()
