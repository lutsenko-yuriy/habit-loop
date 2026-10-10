import os
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

from skill_router import config
from skill_router.config import load_config

_HAS_TOMLLIB = config.tomllib is not None


class TestLocalModelsEnabled(unittest.TestCase):

    def _write_toml(self, tmp_dir: str, content: str) -> str:
        path = Path(tmp_dir) / "skill_router.toml"
        path.write_text(content, encoding="utf-8")
        return str(path)

    @unittest.skipUnless(_HAS_TOMLLIB, "requires tomllib (Python >= 3.11) to actually parse the toml")
    @patch.dict("os.environ", {}, clear=True)
    def test_defaults_to_enabled_when_key_absent(self):
        with TemporaryDirectory() as tmp:
            toml_path = self._write_toml(tmp, "[core]\nmodel_tiers_path = \"docs/MODEL_TIERS.md\"\n")
            cfg = load_config(toml_path)
        self.assertTrue(cfg.local_models_enabled)

    @patch.dict("os.environ", {}, clear=True)
    def test_disabled_when_toml_sets_false(self):
        with TemporaryDirectory() as tmp:
            toml_path = self._write_toml(tmp, "[core]\nlocal_models_enabled = false\n")
            cfg = load_config(toml_path)
        self.assertFalse(cfg.local_models_enabled)

    @unittest.skipUnless(_HAS_TOMLLIB, "requires tomllib (Python >= 3.11) to actually parse the toml")
    @patch.dict("os.environ", {}, clear=True)
    def test_enabled_when_toml_sets_true(self):
        with TemporaryDirectory() as tmp:
            toml_path = self._write_toml(tmp, "[core]\nlocal_models_enabled = true\n")
            cfg = load_config(toml_path)
        self.assertTrue(cfg.local_models_enabled)

    @patch.dict("os.environ", {}, clear=True)
    def test_defaults_to_enabled_when_toml_missing(self):
        cfg = load_config("no/such/skill_router.toml")
        self.assertTrue(cfg.local_models_enabled)

    @patch.dict("os.environ", {}, clear=True)
    @patch("skill_router.config.tomllib", None)
    def test_fails_closed_when_toml_exists_but_unparseable(self):
        """An unreadable toml (e.g. no tomllib) must not fall through to enabled."""
        with TemporaryDirectory() as tmp:
            toml_path = self._write_toml(tmp, "[core]\nlocal_models_enabled = false\n")
            cfg = load_config(toml_path)
        self.assertFalse(cfg.local_models_enabled)

    @patch.dict("os.environ", {}, clear=True)
    @patch("skill_router.config.tomllib", None)
    def test_warns_when_toml_exists_but_unparseable(self):
        with TemporaryDirectory() as tmp:
            toml_path = self._write_toml(tmp, "[core]\n")
            with patch("sys.stderr") as mock_stderr:
                load_config(toml_path)
        written = "".join(call.args[0] for call in mock_stderr.write.call_args_list)
        self.assertIn("tomllib unavailable", written)

    @patch.dict("os.environ", {}, clear=True)
    def test_default_toml_path_is_cwd_independent(self):
        """No explicit toml_path must still resolve to the real repo toml from any cwd."""
        repo_toml = Path(config.__file__).resolve().parents[2] / "skill_router.toml"
        expected = load_config(repo_toml).local_models_enabled

        original_cwd = os.getcwd()
        with TemporaryDirectory() as tmp:
            os.chdir(tmp)
            try:
                cfg = load_config()
            finally:
                os.chdir(original_cwd)
        self.assertEqual(cfg.local_models_enabled, expected)

    @unittest.skipUnless(_HAS_TOMLLIB, "requires tomllib (Python >= 3.11) to actually parse the toml")
    @patch.dict("os.environ", {}, clear=True)
    def test_non_boolean_value_fails_closed(self):
        """A quoted "false" is truthy in Python — must not read as enabled."""
        with TemporaryDirectory() as tmp:
            toml_path = self._write_toml(tmp, '[core]\nlocal_models_enabled = "false"\n')
            cfg = load_config(toml_path)
        self.assertFalse(cfg.local_models_enabled)


@unittest.skipUnless(_HAS_TOMLLIB, "requires tomllib (Python >= 3.11) to actually parse the toml")
@patch.dict("os.environ", {}, clear=True)
class TestLinearProjectId(unittest.TestCase):
    """[project].project_id is the single record (HAB-278); [linear].project_id is the legacy fallback."""

    def _cfg(self, content: str):
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "skill_router.toml"
            path.write_text(content, encoding="utf-8")
            return load_config(str(path))

    def test_project_id_is_read(self):
        self.assertEqual(self._cfg('[project]\nproject_id = " p1 "\n').linear_project_id, "p1")

    def test_project_id_wins_over_legacy_linear(self):
        cfg = self._cfg('[project]\nproject_id = "p1"\n\n[linear]\nproject_id = "old"\n')
        self.assertEqual(cfg.linear_project_id, "p1")

    def test_empty_project_id_keeps_legacy_linear(self):
        cfg = self._cfg('[project]\nproject_id = ""\n\n[linear]\nproject_id = "old"\n')
        self.assertEqual(cfg.linear_project_id, "old")

    def test_env_wins_over_project_id(self):
        with patch.dict("os.environ", {"LINEAR_PROJECT_ID": "env"}):
            cfg = self._cfg('[project]\nproject_id = "p1"\n')
        self.assertEqual(cfg.linear_project_id, "env")

    def test_no_project_id_anywhere(self):
        self.assertIsNone(self._cfg('[providers]\npm = "linear"\n').linear_project_id)


if __name__ == "__main__":
    unittest.main()
