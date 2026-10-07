"""检查仓库自有源代码的单文件 500 行上限，包含注释和空行。"""

import argparse
import os
from pathlib import Path
import sys

LIMIT = 500
EXTENSIONS = {
    ".gd", ".gdshader", ".py", ".cs", ".go", ".js", ".jsx", ".ts", ".tsx",
    ".c", ".cpp", ".cc", ".h", ".hpp", ".rs", ".java", ".swift", ".sh",
    ".ps1", ".bat", ".cmd", ".html", ".css", ".scss", ".sql",
}
EXCLUDED = {".git", ".godot", ".tools", ".venv", "node_modules", "__pycache__", "build", "dist"}


def inspect(root):
    """仅跳过固定的依赖/生成目录；所有自有源码目录均参与检查。"""
    files = []
    for directory, names, filenames in os.walk(root):
        names[:] = sorted(name for name in names if name not in EXCLUDED)
        for name in sorted(filenames):
            path = Path(directory) / name
            if path.suffix.lower() in EXTENSIONS:
                count = len(path.read_text(encoding="utf-8-sig").splitlines())
                files.append((path.relative_to(root), count))
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    if not args.root.is_dir():
        parser.error("检查根目录不存在")
    try:
        files = inspect(args.root.resolve())
    except (OSError, UnicodeError) as error:
        print(f"无法完成源码检查：{error}", file=sys.stderr)
        return 1
    violations = [(path, count) for path, count in files if count > LIMIT]
    for path, count in violations:
        print(f"超限：{path} 共 {count} 行，上限 {LIMIT}", file=sys.stderr)
    largest = max(files, key=lambda item: item[1], default=("无源码", 0))
    print(f"检查 {len(files)} 个源码文件；最长 {largest[0]}：{largest[1]} 行；超限 {len(violations)} 个。")
    return 1 if violations else 0


if __name__ == "__main__":
    sys.exit(main())
