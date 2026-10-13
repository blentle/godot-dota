"""终止真实开发服务器，读取同一权威存档重启，验证双客户端原席位恢复。"""

from __future__ import annotations

import argparse
from contextlib import ExitStack
from pathlib import Path
import socket
import subprocess
import tempfile
import time

from test_network_pair import _client_command, _run_client, _stop, _wait_ready


def wait_marker(process, path: Path, marker: str, timeout: int) -> None:
    """独立文件读取不改变子进程输出文件的写入位置。"""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        text = path.read_text()
        if marker in text:
            return
        if process.poll() is not None or "ERROR:" in text:
            raise RuntimeError("客户端准备失败：\n" + text)
        time.sleep(0.05)
    raise RuntimeError("等待客户端状态超时：" + marker + "\n" + path.read_text())


def run(engine: Path) -> None:
    root = Path(__file__).resolve().parents[1]
    base = [str(engine.resolve()), "--headless", "--path", str(root / "game")]
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    with tempfile.TemporaryDirectory(prefix="dota-restart-") as directory, ExitStack() as cleanup:
        folder = Path(directory)
        checkpoint = folder / "authority.bin"
        command = base + ["--script", "res://tests/network_server.gd", "--", f"--port={port}", "--shared", f"--checkpoint={checkpoint}"]
        log = cleanup.enter_context((folder / "before.log").open("w+"))
        server = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
        cleanup.callback(_stop, server)
        _wait_ready(log, server)
        clients = []
        for index in range(2):
            path = folder / f"client-{index}.log"
            output = cleanup.enter_context(path.open("w"))
            process = subprocess.Popen(_client_command(base, port, "restart_scene"), stdout=output, stderr=subprocess.STDOUT)
            cleanup.callback(_stop, process)
            clients.append((process, path))
        for process, path in clients:
            wait_marker(process, path, "RESTART_READY", 20)
        if not checkpoint.is_file():
            raise RuntimeError("已确认交易之前未生成权威存档")
        # 只终止本工具启动的服务端，模拟进程意外退出，不执行其清理逻辑。
        server.kill()
        server.wait(timeout=5)
        for process, path in clients:
            wait_marker(process, path, "RESTART_WAITING", 15)
        restarted_log = cleanup.enter_context((folder / "after.log").open("w+"))
        restarted = subprocess.Popen(command, stdout=restarted_log, stderr=subprocess.STDOUT)
        cleanup.callback(_stop, restarted)
        _wait_ready(restarted_log, restarted)
        for process, path in clients:
            code = process.wait(timeout=35)
            text = path.read_text()
            if code or "RESTART_CLIENT_PASS" not in text or "ERROR:" in text:
                raise RuntimeError("恢复失败：\n" + text + "\n服务端：\n" + (folder / "after.log").read_text())
            print("RESTART_CLIENT_PASS")
        _run_client(base, port, "shared_waiting", 20, "SHARED_WAITING_PASS", "恢复局清理后新局")
        if restarted.poll() is not None or "ERROR:" in (folder / "after.log").read_text():
            raise RuntimeError("恢复后的服务器异常：\n" + (folder / "after.log").read_text())
        print("双客户端真实服务器进程重启恢复通过。")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    args = parser.parse_args()
    if not args.godot.is_file():
        parser.error("Godot 可执行文件不存在")
    run(args.godot)


if __name__ == "__main__":
    main()
