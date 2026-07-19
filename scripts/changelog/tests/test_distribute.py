import os
import tempfile
import textwrap
import unittest

from changelog.distribute import should_distribute


def _tmp(content: str) -> str:
    f = tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False, encoding='utf-8')
    f.write(textwrap.dedent(content))
    f.close()
    return f.name


class TestShouldDistribute(unittest.TestCase):

    # --- distributing cases ---

    def test_user_bullet_triggers_distribution(self):
        path = _tmp("""\
            ## [1.0.0] — 2026-01-01
            - [user] Button label improved.
        """)
        try:
            self.assertTrue(should_distribute(path, '0.0.0'))
        finally:
            os.unlink(path)

    def test_app_bullet_triggers_distribution(self):
        path = _tmp("""\
            ## [1.0.0] — 2026-01-01
            - [app] Refactored persistence layer.
        """)
        try:
            self.assertTrue(should_distribute(path, '0.0.0'))
        finally:
            os.unlink(path)

    def test_user_and_meta_triggers_distribution(self):
        """An entry mixing [user] and [meta] bullets should still distribute."""
        path = _tmp("""\
            ## [1.0.0] — 2026-01-01
            - [user] New onboarding screen.
            - [meta] Updated plan skill.
        """)
        try:
            self.assertTrue(should_distribute(path, '0.0.0'))
        finally:
            os.unlink(path)

    def test_any_new_entry_with_app_triggers_distribution(self):
        """If one of multiple new entries has [app], the result is true."""
        path = _tmp("""\
            ## [1.1.0] — 2026-02-01
            - [app] DB migration.

            ## [1.0.0] — 2026-01-01
            - [meta] Skill update.
        """)
        try:
            self.assertTrue(should_distribute(path, '0.0.0'))
        finally:
            os.unlink(path)

    # --- non-distributing cases ---

    def test_meta_only_skips_distribution(self):
        path = _tmp("""\
            ## [1.0.0] — 2026-01-01
            - [meta] Updated describe-feature skill.
        """)
        try:
            self.assertFalse(should_distribute(path, '0.0.0'))
        finally:
            os.unlink(path)

    def test_ci_only_skips_distribution(self):
        path = _tmp("""\
            ## [1.0.0] — 2026-01-01
            - [ci] Fixed CHANGELOG lint step.
        """)
        try:
            self.assertFalse(should_distribute(path, '0.0.0'))
        finally:
            os.unlink(path)

    def test_user_none_skips_distribution(self):
        path = _tmp("""\
            ## [1.0.0] — 2026-01-01
            - [user-none]
            - [non-user] Internal refactor.
        """)
        try:
            self.assertFalse(should_distribute(path, '0.0.0'))
        finally:
            os.unlink(path)

    def test_non_user_only_skips_distribution(self):
        path = _tmp("""\
            ## [1.0.0] — 2026-01-01
            - [non-user] Just a developer note.
        """)
        try:
            self.assertFalse(should_distribute(path, '0.0.0'))
        finally:
            os.unlink(path)

    def test_wip_only_skips_build(self):
        path = _tmp("""\
            ## [1.0.0] — 2026-01-01
            - [wip] Intermediate WU merge.
        """)
        try:
            self.assertFalse(should_distribute(path, '0.0.0'))
        finally:
            os.unlink(path)

    def test_test_only_skips_build(self):
        path = _tmp("""\
            ## [1.0.0] — 2026-01-01
            - [test] Added integration scenarios.
        """)
        try:
            self.assertFalse(should_distribute(path, '0.0.0'))
        finally:
            os.unlink(path)

    def test_meta_and_ci_together_skips_distribution(self):
        path = _tmp("""\
            ## [1.0.0] — 2026-01-01
            - [meta] New skill.
            - [ci] Lint fix.
        """)
        try:
            self.assertFalse(should_distribute(path, '0.0.0'))
        finally:
            os.unlink(path)

    def test_no_new_entries_returns_false(self):
        path = _tmp("""\
            ## [0.9.0] — 2025-12-01
            - [user] Old feature.
        """)
        try:
            self.assertFalse(should_distribute(path, '0.9.0'))
        finally:
            os.unlink(path)

    def test_all_new_entries_meta_returns_false(self):
        path = _tmp("""\
            ## [1.1.0] — 2026-02-01
            - [meta] Skill A.

            ## [1.0.0] — 2026-01-01
            - [ci] Lint fix.
        """)
        try:
            self.assertFalse(should_distribute(path, '0.0.0'))
        finally:
            os.unlink(path)

    # --- version filtering ---

    def test_only_new_entries_are_considered(self):
        """Entries at or below last_published_version must be ignored."""
        path = _tmp("""\
            ## [1.0.0] — 2026-01-01
            - [meta] New skill (newer entry, no dist).

            ## [0.9.0] — 2025-12-01
            - [user] Old user change (must be ignored).
        """)
        try:
            self.assertFalse(should_distribute(path, '0.9.0'))
        finally:
            os.unlink(path)

    # --- HAB-185: sealed ## [Unreleased] sections between numbered releases ---

    def test_sealed_unreleased_bullet_does_not_leak_into_newer_entry(self):
        """A [user] bullet in a sealed Unreleased batch (sandwiched between two
        numbered releases) must not make the OLDER, meta-only release above it
        look distributable."""
        path = _tmp("""\
            ## [Unreleased]
            - [ci] currently open batch, ignored regardless.

            ## [1.1.0] — 2026-02-01
            - [meta] Skill A only — should NOT trigger distribution on its own.

            ## [Unreleased]
            - [user] sealed batch bullet — must not leak into 1.1.0's body.

            ## [1.0.0] — 2026-01-01
            - [user] Old user change.
        """)
        try:
            self.assertFalse(should_distribute(path, '1.0.0'))
        finally:
            os.unlink(path)
