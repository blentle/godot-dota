"""启动两个独立 Godot 进程，验证本机权威网络链路；退出时回收子进程。"""

from __future__ import annotations

import argparse
from pathlib import Path
import socket
import subprocess
import tempfile
import time


def run(engine: Path, root: Path, scene: bool = False, capture: Path | None = None) -> None:
    """先等待服务端就绪，再运行客户端；任一异常都使验证失败。"""
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    common = [str(engine.resolve()), "--headless", "--path", str(root / "game")]
    with tempfile.TemporaryFile(mode="w+", encoding="utf-8") as log:
        server_args = ["--script", "res://tests/network_server.gd", "--", f"--port={port}"]
        if scene:
            server_args.append("--shutdown-after=20")
        server = subprocess.Popen(common + server_args, stdout=log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                log.seek(0)
                output = log.read()
                if server.poll() is not None:
                    raise RuntimeError("服务端提前退出：\n" + output)
                if "NETWORK_SERVER_READY" in output:
                    break
                time.sleep(0.05)
            else:
                raise RuntimeError("服务端启动超时：\n" + output)
            for attempt in range(1 if scene else 2):
                client_args = common.copy()
                if capture:
                    client_args.remove("--headless")
                    capture.mkdir(parents=True, exist_ok=True)
                script = "network_scene" if scene else "network_client"
                client_args += ["--script", f"res://tests/{script}.gd", "--", f"--port={port}"]
                if capture:
                    client_args.append(f"--output-dir={capture.resolve()}")
                client = subprocess.run(client_args, capture_output=True, text=True, timeout=40 if scene else 18)
                print(client.stdout, end="")
                marker = "NETWORK_SCENE_PASS" if scene else "NETWORK_CLIENT_PASS"
                if client.returncode != 0 or marker not in client.stdout or "ERROR:" in client.stderr:
                    raise RuntimeError(f"第 {attempt + 1} 次客户端验证失败：\n" + client.stderr)
            log.seek(0)
            output = log.read()
            if (not scene and server.poll() is not None) or (scene and server.poll() not in [None, 0]) or "ERROR:" in output:
                raise RuntimeError("服务端运行异常：\n" + output)
            print("双进程网络验证通过。")
        finally:
            server.terminate()
            try:
                server.wait(timeout=3)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait(timeout=3)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path, help="Godot 可执行文件路径")
    parser.add_argument("--scene", action="store_true", help="验证图形场景及服务端退出后的断线状态")
    parser.add_argument("--capture", type=Path, help="显示真实窗口并保存场景截图，需要同时指定 --scene")
    args = parser.parse_args()
    if not args.godot.is_file():
        parser.error("Godot 可执行文件不存在")
    if args.capture and not args.scene:
        parser.error("截图需要同时指定 --scene")
    run(args.godot, Path(__file__).resolve().parents[1], args.scene, args.capture)


if __name__ == "__main__":
    main()
