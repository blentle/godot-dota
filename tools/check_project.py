"""工程统一回归入口：检查工具、全部规则与离线场景，可选真实进程网络回归。"""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def execute(label: str, command: list[str], expected: int = 0, timeout: int = 120) -> None:
    """Godot 脚本错误有时仍返回零，必须同时检查标准输出与错误输出。"""
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
    output = result.stdout + result.stderr
    if result.returncode != expected or (expected == 0 and "ERROR:" in output):
        raise RuntimeError(f"{label} 失败（退出码 {result.returncode}）：\n{output}")
    print(f"通过：{label}", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--network", action="store_true", help="额外验证串行、并发、异常与网络场景")
    args = parser.parse_args()
    if not args.godot.is_file():
        parser.error("Godot 可执行文件不存在")
    engine = str(args.godot.resolve())
    base = [engine, "--headless", "--path", str(ROOT / "game")]
    try:
        execute("源码行数", [sys.executable, "tools/check_source_limits.py"])
        execute("Python 工具测试", [sys.executable, "-m", "unittest", "discover", "-s", "tests", "-v"])
        execute("开发内容清单", [sys.executable, "tools/validate_content.py"])
        for test in sorted((ROOT / "game/tests").glob("test_*.gd")):
            execute(test.name, base + ["--script", "res://tests/" + test.name])
        execute("离线训练场景", base + ["--", "--smoke-test"])
        execute("三路兵线场景", base + ["--", "--lanes", "--smoke-test"])
        execute("引擎内容入口", base + ["--", "--validate-content"])
        execute("正式服务器入口仍拒绝启动", base + ["--", "--server"], expected=2)
        if args.network:
            command = [sys.executable, "tools/test_network_pair.py", "--godot", engine]
            for mode in [[], ["--concurrent"], ["--anomaly"], ["--scene"]]:
                execute("网络 " + (" ".join(mode) or "串行"), command + mode)
    except (RuntimeError, subprocess.TimeoutExpired, OSError) as error:
        print(error, file=sys.stderr)
        return 1
    print("工程回归通过；不代表正式英雄、UI 还原、十人对战或跨平台发布已验收。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
