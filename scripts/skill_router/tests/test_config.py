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


if __name__ == "__main__":
    unittest.main()
