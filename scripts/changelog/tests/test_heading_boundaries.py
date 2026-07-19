import textwrap
import unittest

from changelog.heading_boundaries import body_end_for, heading_starts


class TestHeadingStarts(unittest.TestCase):

    def test_finds_numeric_and_unreleased_headings(self):
        content = textwrap.dedent("""\
            # Changelog

            ---

            ## [Unreleased]

            - [ci] first.

            ## [0.51.0] — 2026-07-19

            - [user] second.

            ## [Unreleased]

            - [meta] third.

            ## [0.50.0] — 2026-07-18

            - [user] fourth.
        """)
        starts = heading_starts(content)
        headings = [content[s:content.index('\n', s)] for s in starts]
        self.assertEqual(
            headings,
            ['## [Unreleased]', '## [0.51.0] — 2026-07-19', '## [Unreleased]', '## [0.50.0] — 2026-07-18'],
        )

    def test_empty_content_has_no_headings(self):
        self.assertEqual(heading_starts(''), [])


class TestBodyEndFor(unittest.TestCase):

    def test_sealed_unreleased_does_not_leak_into_newer_entrys_body(self):
        content = textwrap.dedent("""\
            ## [0.51.0] — 2026-07-19
            - [user] newer release bullet.

            ## [Unreleased]
            - [user-none] sealed batch bullet.

            ## [0.50.0] — 2026-07-18
            - [user] older release bullet.
        """)
        starts = heading_starts(content)
        # starts[0] = ## [0.51.0], starts[1] = ## [Unreleased], starts[2] = ## [0.50.0]
        body_end = body_end_for(starts[0], starts, len(content))
        body = content[starts[0]:body_end]
        self.assertIn('newer release bullet', body)
        self.assertNotIn('sealed batch bullet', body)

    def test_last_heading_body_runs_to_end_of_content(self):
        content = "## [1.0.0]\n- [user] only entry.\n"
        starts = heading_starts(content)
        body_end = body_end_for(starts[0], starts, len(content))
        self.assertEqual(body_end, len(content))

    def test_no_unreleased_present_behaves_like_next_numeric_heading(self):
        content = textwrap.dedent("""\
            ## [1.1.0] — 2026-07-19
            - [user] newest.

            ## [1.0.0] — 2026-07-18
            - [user] oldest.
        """)
        starts = heading_starts(content)
        body_end = body_end_for(starts[0], starts, len(content))
        body = content[starts[0]:body_end]
        self.assertIn('newest', body)
        self.assertNotIn('oldest', body)


if __name__ == '__main__':
    unittest.main()
