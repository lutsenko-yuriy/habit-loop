#!/usr/bin/env python3
"""Test runner for skill_router — run with: python3 scripts/test_skill_router.py

Discovers and runs all tests from the test_skill_router package.
"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from test_skill_router.test_streaming import TestAuthHeaders, TestModelLoaded, TestStreamCompletion
from test_skill_router.test_frontmatter import TestNormalizeModelName, TestReadFrontmatter, TestLookupLmstudioModel
from test_skill_router.test_tool_loop import TestBuildTools, TestExecuteTool, TestChatCompletionWithTools
from test_skill_router.test_linear_client import TestFetchLinearContext, TestFormatLinearContext
from test_skill_router.test_main import TestMain

if __name__ == "__main__":
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    for cls in [
        TestAuthHeaders, TestModelLoaded, TestStreamCompletion,
        TestNormalizeModelName, TestReadFrontmatter, TestLookupLmstudioModel,
        TestBuildTools, TestExecuteTool, TestChatCompletionWithTools,
        TestFetchLinearContext, TestFormatLinearContext,
        TestMain,
    ]:
        suite.addTests(loader.loadTestsFromTestCase(cls))
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
