"""启动一个共享服务端与多个图形客户端，核对共同 tick 的公共世界状态。"""

from __future__ import annotations

import argparse
from contextlib import ExitStack
import json
from pathlib import Path
import socket
import subprocess
import tempfile

from udp_impairment import UdpImpairment

from test_network_pair import _client_command, _run_client, _stop, _wait_ready


def run(engine: Path, capture: Path | None = None, players: int = 2, impaired: bool = False, soak_seconds: int = 0) -> None:
    root = Path(__file__).resolve().parents[1]
    base = [str(engine.resolve()), "--headless", "--path", str(root / "game")]
    if capture:
        capture.mkdir(parents=True, exist_ok=True)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    running = []
    relays = []
    with tempfile.TemporaryFile(mode="w+", encoding="utf-8") as log:
        server = subprocess.Popen(base + ["--script", "res://tests/network_server.gd", "--",
                                          f"--port={port}", "--shared", f"--players={players}"], stdout=log, stderr=subprocess.STDOUT)
        try:
            _wait_ready(log, server)
            for _ in range(players):
                client_port = port
                if impaired:
                    relay = UdpImpairment(port)
                    relays.append(relay)
                    client_port = relay.port
                output = tempfile.TemporaryFile(mode="w+", encoding="utf-8")
                try:
                    command = _client_command(base, client_port, "shared_scene", capture)
                    command.append(f"--soak-seconds={soak_seconds}")
                    process = subprocess.Popen(command,
                                               stdout=output, stderr=subprocess.STDOUT)
                except BaseException:
                    output.close()
                    raise
                running.append((process, output))
            records = []
            for process, output in running:
                code = process.wait(timeout=45 + soak_seconds * 3)
                output.seek(0)
                text = output.read()
                if code or "SHARED_SCENE_PASS" not in text or "ERROR:" in text:
                    raise RuntimeError("多人客户端失败：\n" + text)
                for line in text.splitlines():
                    if line.startswith("SHARED_SIGNATURES "):
                        records.append(json.loads(line.removeprefix("SHARED_SIGNATURES ")))
                    elif "SHARED_SCENE_PASS" in line:
                        print(line)
            if len(records) != players or {row["slot"] for row in records} != set(range(players)):
                raise RuntimeError("未取得全部独立席位结果")
            if len({row["entity"] for row in records}) != players:
                raise RuntimeError("不同客户端被分配到同一英雄")
            if any(row["team"] != row["slot"] % 2 for row in records):
                raise RuntimeError("阵营分配不符合席位表")
            common = set.intersection(*(set(row["states"]) for row in records))
            if len(common) < 3:
                raise RuntimeError("共同 tick 不足，不能证明世界同步")
            for tick in common:
                if len({row["states"][tick] for row in records}) != 1:
                    raise RuntimeError(f"tick {tick} 的各客户端世界状态不一致")
            if impaired:
                for relay in relays:
                    stats = relay.statistics()
                    for direction in ["up", "down"]:
                        if any(stats[direction][key] == 0 for key in ["dropped", "duplicated", "forwarded"]):
                            raise RuntimeError("未实际覆盖双向丢包、重复与转发：" + str(stats))
                    print("UDP_IMPAIRMENT " + json.dumps(stats))
            _run_client(base, port, "shared_waiting", 20, "SHARED_WAITING_PASS", "共享局清理后新会话")
            log.seek(0)
            server_output = log.read()
            if server.poll() is not None or "ERROR:" in server_output:
                raise RuntimeError("共享服务端异常：\n" + server_output)
            print(f"{players} 玩家 / {players + 1} 进程验证通过，共同世界摘要一致：{len(common)} 个 tick。")
        except (RuntimeError, subprocess.TimeoutExpired):
            for index, (_, output) in enumerate(running):
                output.seek(0)
                print(f"失败现场 客户端 {index}:\n" + output.read()[-3000:])
            log.seek(0)
            server_text = log.read()
            print("失败现场 服务端首尾:\n" + server_text[:7000] + "\n...\n" + server_text[-1000:])
            raise
        finally:
            # 即使其中一次清理抛错，也继续回收其余资源。
            with ExitStack() as cleanup:
                cleanup.callback(_stop, server)
                for relay in relays:
                    cleanup.callback(relay.close)
                for process, output in running:
                    cleanup.callback(output.close)
                    cleanup.callback(_stop, process)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--capture", type=Path, help="打开所选人数的真实窗口并按席位保存截图")
    parser.add_argument("--players", type=int, choices=[2, 4, 10], default=2, help="共享对局席位数")
    parser.add_argument("--impaired", action="store_true", help="双向 UDP 延迟、抖动、丢包和重复注入")
    parser.add_argument("--soak-seconds", type=int, default=0, help="额外持续运行的模拟秒数（0～300）")
    args = parser.parse_args()
    if not 0 <= args.soak_seconds <= 300:
        parser.error("持续运行秒数必须在 0～300 之间")
    if not args.godot.is_file():
        parser.error("Godot 可执行文件不存在")
    run(args.godot, args.capture, args.players, args.impaired, args.soak_seconds)


if __name__ == "__main__":
    main()
