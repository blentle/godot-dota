"""确认行数门禁包含空行，并正确处理边界与依赖目录。"""

from pathlib import Path
import tempfile
import unittest

from tools.check_source_limits import inspect, LIMIT


class SourceLimitTests(unittest.TestCase):
    def test_includes_empty_lines_and_exact_boundary(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "valid.gd").write_text("# 中文注释\n" + "\n" * 499, encoding="utf-8")
            (root / "large.py").write_text("\n" * 501, encoding="utf-8")
            counts = dict(inspect(root))
            self.assertEqual(counts[Path("valid.gd")], LIMIT)
            self.assertGreater(counts[Path("large.py")], LIMIT)

    def test_excludes_engine_but_checks_nested_business_code(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for folder in [".tools", "game/rules"]:
                (root / folder).mkdir(parents=True)
                (root / folder / "sample.gd").write_text("\n" * 501)
            self.assertEqual(inspect(root), [(Path("game/rules/sample.gd"), 501)])


if __name__ == "__main__":
    unittest.main()
