"""启动两个独立 Godot 进程，验证本机权威网络链路；退出时回收子进程。"""

from __future__ import annotations

import argparse
from pathlib import Path
import socket
import subprocess
import tempfile
import time


def _wait_ready(log, server: subprocess.Popen) -> None:
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        log.seek(0)
        output = log.read()
        if server.poll() is not None:
            raise RuntimeError("服务端提前退出：\n" + output)
        if "NETWORK_SERVER_READY" in output:
            return
        time.sleep(0.05)
    raise RuntimeError("服务端启动超时：\n" + output)


def _client_command(common: list[str], port: int, script: str, capture: Path | None = None) -> list[str]:
    """引擎参数放在分隔符之前，脚本参数放在之后。"""
    command = common.copy()
    if capture:
        command.remove("--headless")
    command += ["--script", f"res://tests/{script}.gd", "--", f"--port={port}"]
    if capture:
        command.append(f"--output-dir={capture.resolve()}")
    return command


def _stop(process: subprocess.Popen) -> None:
    """只回收本工具启动且仍存活的进程，并等待操作系统释放资源。"""
    if process.poll() is None:
        process.terminate()
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=3)


def _run_client(common: list[str], port: int, script: str, timeout: int, marker: str,
                label: str, capture: Path | None = None) -> None:
    client = subprocess.run(_client_command(common, port, script, capture),
                            capture_output=True, text=True, timeout=timeout)
    output = client.stdout + client.stderr
    print(client.stdout, end="")
    if client.returncode != 0 or marker not in output or "ERROR:" in output:
        raise RuntimeError(f"{label}客户端验证失败：\n" + output)


def _run_concurrent(common: list[str], port: int) -> None:
    """任一并发客户端失败也必须回收所有已启动客户端。"""
    running = []
    try:
        for _ in range(2):
            output = tempfile.TemporaryFile(mode="w+", encoding="utf-8")
            try:
                process = subprocess.Popen(_client_command(common, port, "network_client"),
                                           stdout=output, stderr=subprocess.STDOUT, text=True)
            except BaseException:
                output.close()
                raise
            running.append((process, output))
        for process, output in running:
            code = process.wait(timeout=30)
            output.seek(0)
            text = output.read()
            print(text, end="")
            if code != 0 or "NETWORK_CLIENT_PASS" not in text or "ERROR:" in text:
                raise RuntimeError("并发独立会话验证失败：\n" + text)
    finally:
        for process, output in running:
            _stop(process)
            output.close()


def run(engine: Path, root: Path, scene: bool = False, capture: Path | None = None,
        anomaly: bool = False, concurrent: bool = False) -> None:
    """先等待服务端就绪，再运行客户端；任一异常都使验证失败。"""
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    common = [str(engine.resolve()), "--headless", "--path", str(root / "game")]
    with tempfile.TemporaryFile(mode="w+", encoding="utf-8") as log:
        server_args = ["--script", "res://tests/network_server.gd", "--", f"--port={port}"]
        if scene:
            server_args.append("--shutdown-after=20")
        if anomaly:
            server_args.append("--delay-ms=180")
        server = subprocess.Popen(common + server_args, stdout=log, stderr=subprocess.STDOUT)
        try:
            _wait_ready(log, server)
            if anomaly:
                _run_client(common, port, "network_anomaly", 90, "NETWORK_ANOMALY_PASS", "异常注入")
            elif concurrent:
                _run_concurrent(common, port)
            else:
                if capture:
                    capture.mkdir(parents=True, exist_ok=True)
                for attempt in range(1 if scene else 2):
                    script = "network_scene" if scene else "network_client"
                    marker = "NETWORK_SCENE_PASS" if scene else "NETWORK_CLIENT_PASS"
                    _run_client(common, port, script, 40 if scene else 18,
                                marker, f"第 {attempt + 1} 次", capture)
            log.seek(0)
            output = log.read()
            if (not scene and server.poll() is not None) or (scene and server.poll() not in [None, 0]) or "ERROR:" in output:
                raise RuntimeError("服务端运行异常：\n" + output)
            print("双进程网络验证通过。")
        finally:
            _stop(server)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path, help="Godot 可执行文件路径")
    parser.add_argument("--scene", action="store_true", help="验证图形场景及服务端退出后的断线状态")
    parser.add_argument("--capture", type=Path, help="显示真实窗口并保存场景截图，需要同时指定 --scene")
    parser.add_argument("--anomaly", action="store_true", help="以慢服务器验证突发、停顿与待确认上限")
    parser.add_argument("--concurrent", action="store_true", help="两个客户端同时连接，验证多席位并行")
    args = parser.parse_args()
    if not args.godot.is_file():
        parser.error("Godot 可执行文件不存在")
    if args.capture and not args.scene:
        parser.error("截图需要同时指定 --scene")
    if sum([args.scene, args.anomaly, args.concurrent]) > 1:
        parser.error("场景、异常与并发模式只能选择一种")
    run(args.godot, Path(__file__).resolve().parents[1], args.scene, args.capture,
        args.anomaly, args.concurrent)


if __name__ == "__main__":
    main()
