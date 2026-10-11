"""真实双客户端网络分区测试：隔离一方或全员十二秒，再恢复原连接入口。"""

from __future__ import annotations

import argparse
from contextlib import ExitStack
from pathlib import Path
import socket
import subprocess
import tempfile
import time

from test_network_pair import _client_command, _run_client, _stop, _wait_ready
from udp_impairment import UdpImpairment


def run(engine: Path, all_disconnected: bool = False) -> None:
    root = Path(__file__).resolve().parents[1]
    base = [str(engine.resolve()), "--headless", "--path", str(root / "game")]
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    with ExitStack() as cleanup:
        server_log = cleanup.enter_context(tempfile.TemporaryFile(mode="w+", encoding="utf-8"))
        server = subprocess.Popen(base + ["--script", "res://tests/network_server.gd", "--",
                                          f"--port={port}", "--shared"], stdout=server_log, stderr=subprocess.STDOUT)
        cleanup.callback(_stop, server)
        _wait_ready(server_log, server)
        relays = []
        clients = []
        for observer in [False, not all_disconnected]:
            destination = port
            if not observer:
                relay = UdpImpairment(port)
                relays.append(relay)
                cleanup.callback(relay.close)
                destination = relay.port
            log = cleanup.enter_context(tempfile.TemporaryFile(mode="w+", encoding="utf-8"))
            command = _client_command(base, destination, "reconnect_scene")
            if observer:
                command.append("--observer")
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            cleanup.callback(_stop, process)
            clients.append((process, log))
        deadline = time.monotonic() + 18
        for process, log in clients[:2 if all_disconnected else 1]:
            while True:
                log.seek(0)
                output = log.read()
                if "PARTITION_READY" in output:
                    break
                if process.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError("客户端未准备好分区：\n" + output)
                time.sleep(0.05)
        for relay in relays: relay.partition.set()
        time.sleep(12)
        for relay in relays: relay.partition.clear()
        markers = ["RECONNECT_CLIENT_PASS", "RECONNECT_CLIENT_PASS" if all_disconnected else "RECONNECT_OBSERVER_PASS"]
        for (process, log), marker in zip(clients, markers):
            code = process.wait(timeout=45)
            log.seek(0)
            output = log.read()
            if code or marker not in output or "ERROR:" in output:
                server_log.seek(0)
                raise RuntimeError("网络分区验证失败：\n" + output + "\n服务端：\n" + server_log.read())
            print(marker)
        for relay in relays:
            relay.statistics()
            if relay.partition_dropped == 0:
                raise RuntimeError("网络分区没有实际丢弃数据报")
        _run_client(base, port, "shared_waiting", 20, "SHARED_WAITING_PASS", "主动离场后新局")
        server_log.seek(0)
        if server.poll() is not None or "ERROR:" in server_log.read():
            raise RuntimeError("网络分区期间服务端异常")
        print(f"十二秒网络分区后恢复原席位通过；隔离丢弃 {sum(relay.partition_dropped for relay in relays)} 个数据报。")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--all-disconnected", action="store_true", help="同时隔离所有客户端")
    args = parser.parse_args()
    if not args.godot.is_file():
        parser.error("Godot 可执行文件不存在")
    run(args.godot, args.all_disconnected)


if __name__ == "__main__":
    main()
