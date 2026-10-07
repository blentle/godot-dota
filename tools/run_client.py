"""使用本地 Godot 可执行文件启动桌面客户端。"""

import os
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    root = Path(__file__).resolve().parents[1]
    candidates = [os.environ.get("GODOT_BIN"), shutil.which("godot"), shutil.which("godot4")]
    candidates += [str(root / ".tools/Godot.app/Contents/MacOS/Godot")]
    executable = next((value for value in candidates if value and Path(value).is_file()), None)
    if not executable:
        print("Godot 4.7.2 not found. Install it and set GODOT_BIN to its executable path.", file=sys.stderr)
        return 1
    return subprocess.call([executable, "--path", str(root / "game"), *sys.argv[1:]])


if __name__ == "__main__":
    sys.exit(main())
