"""Run the repository's unit tests with ``src`` available for imports."""

from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "src"
TESTS = ROOT / "tests"
sys.path.insert(0, str(SOURCE))


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.discover(str(TESTS), pattern="test_*.py")
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if result.wasSuccessful() else 1)

