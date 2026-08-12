import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

from skill_router.config import load_config


class TestLocalModelsEnabled(unittest.TestCase):

    def _write_toml(self, tmp_dir: str, content: str) -> str:
        path = Path(tmp_dir) / "skill_router.toml"
        path.write_text(content, encoding="utf-8")
        return str(path)

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
        """A toml file that exists but can't be read (tomllib missing on
        Python < 3.11 — the exact bare `python3` scenario every
        .claude/commands/ stub actually invokes — or malformed content)
        must never silently fall through to the enabled default. Verified
        live: bare python3 on this machine (3.9, no tomllib) was letting
        local_models_enabled=false in the real skill_router.toml go
        unenforced (HAB-221 WU3 audit)."""
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


if __name__ == "__main__":
    unittest.main()
