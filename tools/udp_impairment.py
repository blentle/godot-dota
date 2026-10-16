"""仅供本机回归的 UDP 故障转发器，不解析或修改 ENet 数据内容。"""

from __future__ import annotations

import heapq
import selectors
import socket
import threading
import time


class DatagramPolicy:
    """按方向独立计数，以固定序列注入延迟、抖动、丢弃和重复。"""

    def __init__(self, delay: float = 0.04, jitter: float = 0.02,
                 drop_every: int = 17, duplicate_every: int = 23):
        if delay < jitter or jitter < 0 or drop_every < 0 or duplicate_every < 0:
            raise ValueError("故障参数必须非负且基础延迟不小于抖动")
        self.delay = delay
        self.jitter = jitter
        self.drop_every = drop_every
        self.duplicate_every = duplicate_every
        self.count = 0
        self.dropped = 0
        self.duplicated = 0

    def schedule(self, now: float) -> list[float]:
        self.count += 1
        if self.drop_every and self.count % self.drop_every == 0:
            self.dropped += 1
            return []
        offset = ((self.count * 7) % 11 - 5) / 5 * self.jitter
        times = [now + self.delay + offset]
        if self.duplicate_every and self.count % self.duplicate_every == 0:
            self.duplicated += 1
            times.append(times[0] + 0.003)
        return times


class UdpImpairment:
    """每个客户端源地址独享上游套接字，重连不会复用旧传输的服务器地址。"""

    MAX_QUEUE = 4096

    def __init__(self, server_port: int):
        self.server = ("127.0.0.1", server_port)
        self.front = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.upstreams = {}
        self.selector = selectors.DefaultSelector()
        try:
            self.front.bind(("127.0.0.1", 0))
            self.front.setblocking(False)
            self.selector.register(self.front, selectors.EVENT_READ)
        except BaseException:
            self.selector.close()
            self.front.close()
            raise
        self.port = self.front.getsockname()[1]
        self.policies = {"up": DatagramPolicy(), "down": DatagramPolicy()}
        self.forwarded = {"up": 0, "down": 0}
        self.queue = []
        self.serial = 0
        self.error = None
        self.partition = threading.Event()
        self.partition_dropped = 0
        self.stopping = threading.Event()
        self.thread = threading.Thread(target=self._run, name="udp-impairment", daemon=True)
        self.thread.start()

    def _run(self) -> None:
        try:
            while not self.stopping.is_set():
                now = time.monotonic()
                while self.queue and self.queue[0][0] <= now:
                    _, _, sock, destination, payload, direction = heapq.heappop(self.queue)
                    if self.partition.is_set():
                        self.partition_dropped += 1
                        continue
                    sock.sendto(payload, destination)
                    self.forwarded[direction] += 1
                timeout = min(0.01, max(0, self.queue[0][0] - now)) if self.queue else 0.01
                for key, _ in self.selector.select(timeout):
                    payload, address = key.fileobj.recvfrom(65535)
                    if key.fileobj is self.front:
                        direction, target, destination = "up", self._upstream(address), self.server
                    else:
                        if address != self.server:
                            continue
                        direction, target, destination = "down", self.front, key.data
                    if self.partition.is_set():
                        self.partition_dropped += 1
                        continue
                    for deadline in self.policies[direction].schedule(time.monotonic()):
                        if len(self.queue) >= self.MAX_QUEUE:
                            raise RuntimeError("故障转发队列超限，不能悄悄改变测试丢包模型")
                        self.serial += 1
                        heapq.heappush(self.queue, (deadline, self.serial, target,
                                                   destination, payload, direction))
        except BaseException as error:
            self.error = error

    def _upstream(self, client: tuple) -> socket.socket:
        """返回包按原源地址路由；旧连接迟到的数据不得转发给重连后的客户端。"""
        if client not in self.upstreams:
            if len(self.upstreams) >= 64:
                raise RuntimeError("故障转发器客户端地址数量超限")
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            try:
                sock.bind(("127.0.0.1", 0))
                sock.setblocking(False)
                self.selector.register(sock, selectors.EVENT_READ, client)
            except BaseException:
                sock.close()
                raise
            self.upstreams[client] = sock
        return self.upstreams[client]

    def statistics(self) -> dict:
        if self.error:
            raise RuntimeError("UDP 故障转发失败") from self.error
        return {direction: {"received": policy.count, "dropped": policy.dropped,
                            "duplicated": policy.duplicated, "forwarded": self.forwarded[direction]}
                for direction, policy in self.policies.items()}

    def close(self) -> None:
        self.stopping.set()
        self.thread.join(timeout=2)
        if self.thread.is_alive():
            raise RuntimeError("UDP 故障转发线程未停止")
        self.selector.close()
        self.front.close()
        for sock in self.upstreams.values(): sock.close()
        if self.error:
            raise RuntimeError("UDP 故障转发线程失败") from self.error
