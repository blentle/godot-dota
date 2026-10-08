"""启动一个共享服务端与两个图形客户端，核对共同 tick 的公共世界状态。"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import socket
import subprocess
import tempfile

from test_network_pair import _client_command, _run_client, _stop, _wait_ready


def run(engine: Path, capture: Path | None = None) -> None:
    root = Path(__file__).resolve().parents[1]
    base = [str(engine.resolve()), "--headless", "--path", str(root / "game")]
    if capture:
        capture.mkdir(parents=True, exist_ok=True)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    running = []
    with tempfile.TemporaryFile(mode="w+", encoding="utf-8") as log:
        server = subprocess.Popen(base + ["--script", "res://tests/network_server.gd", "--",
                                          f"--port={port}", "--shared"], stdout=log, stderr=subprocess.STDOUT)
        try:
            _wait_ready(log, server)
            for _ in range(2):
                output = tempfile.TemporaryFile(mode="w+", encoding="utf-8")
                try:
                    process = subprocess.Popen(_client_command(base, port, "shared_scene", capture),
                                               stdout=output, stderr=subprocess.STDOUT)
                except BaseException:
                    output.close()
                    raise
                running.append((process, output))
            records = []
            for process, output in running:
                code = process.wait(timeout=45)
                output.seek(0)
                text = output.read()
                if code or "SHARED_SCENE_PASS" not in text or "ERROR:" in text:
                    raise RuntimeError("双玩家客户端失败：\n" + text)
                for line in text.splitlines():
                    if line.startswith("SHARED_SIGNATURES "):
                        records.append(json.loads(line.removeprefix("SHARED_SIGNATURES ")))
                    elif "SHARED_SCENE_PASS" in line:
                        print(line)
            if len(records) != 2 or {row["team"] for row in records} != {0, 1}:
                raise RuntimeError("未取得双方独立验证结果")
            common = records[0]["states"].keys() & records[1]["states"].keys()
            if len(common) < 3:
                raise RuntimeError("共同 tick 不足，不能证明世界同步")
            for tick in common:
                if records[0]["states"][tick] != records[1]["states"][tick]:
                    raise RuntimeError(f"tick {tick} 的双方世界状态不一致")
            _run_client(base, port, "network_client", 18, "NETWORK_CLIENT_PASS", "共享局清理后新会话")
            log.seek(0)
            server_output = log.read()
            if server.poll() is not None or "ERROR:" in server_output:
                raise RuntimeError("共享服务端异常：\n" + server_output)
            print(f"双玩家三进程验证通过，共同世界摘要一致：{len(common)} 个 tick。")
        finally:
            for process, output in running:
                _stop(process)
                output.close()
            _stop(server)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--capture", type=Path, help="打开两个真实窗口并保存各阵营截图")
    args = parser.parse_args()
    if not args.godot.is_file():
        parser.error("Godot 可执行文件不存在")
    run(args.godot, args.capture)


if __name__ == "__main__":
    main()
