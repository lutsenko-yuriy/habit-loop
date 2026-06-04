# -*- coding: utf-8 -*-
#!/usr/bin/env python3
"""
skill_router.py — entry-point shim.

Delegates to the skill_router package. Split into modules under scripts/skill_router/.

Usage:
    python3 scripts/skill_router.py <skill_path> [--args <extra>]

Exit codes:
    0  Skill executed successfully
    1  LM Studio unavailable or the mapped model is not loaded
    2  Skill file not found, unparseable frontmatter, or no lm-studio mapping
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from skill_router import main  # noqa: E402

if __name__ == "__main__":
    main()
