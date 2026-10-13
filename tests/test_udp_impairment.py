"""确定性故障策略测试，避免无效配置和名义丢包但实际未触发。"""

import unittest
import socket
from contextlib import ExitStack

from tools.udp_impairment import DatagramPolicy, UdpImpairment


class DatagramPolicyTests(unittest.TestCase):
    def test_delay_bounds_and_repeatability(self):
        first = DatagramPolicy()
        second = DatagramPolicy()
        for _ in range(100):
            deadlines = first.schedule(10)
            self.assertEqual(deadlines, second.schedule(10))
            for deadline in deadlines:
                self.assertGreaterEqual(deadline, 10.02)
                self.assertLessEqual(deadline, 10.063)
        self.assertEqual(first.dropped, 5)
        self.assertEqual(first.duplicated, 4)

    def test_drop_precedes_duplicate(self):
        policy = DatagramPolicy(drop_every=2, duplicate_every=2)
        self.assertEqual(len(policy.schedule(0)), 1)
        self.assertEqual(policy.schedule(0), [])
        self.assertEqual(policy.duplicated, 0)

    def test_invalid_configuration(self):
        for options in [{"delay": -1}, {"jitter": -1}, {"jitter": 1},
                        {"drop_every": -1}, {"duplicate_every": -1}]:
            with self.assertRaises(ValueError):
                DatagramPolicy(**options)


class UpstreamRoutingTests(unittest.TestCase):
    def test_reconnected_address_keeps_old_replies_isolated(self):
        """两个传输源必须拥有不同上游端口，旧连接回包仍只发给旧源。"""
        with ExitStack() as cleanup:
            sockets = []
            for _ in range(3):
                sock = cleanup.enter_context(socket.socket(socket.AF_INET, socket.SOCK_DGRAM))
                sock.bind(("127.0.0.1", 0))
                sock.settimeout(2)
                sockets.append(sock)
            server, old, new = sockets
            relay = UdpImpairment(server.getsockname()[1])
            cleanup.callback(relay.close)
            relay.policies = {key: DatagramPolicy(0, 0, 0, 0) for key in ("up", "down")}
            old.sendto(b"old", ("127.0.0.1", relay.port))
            payload, old_source = server.recvfrom(64)
            self.assertEqual(payload, b"old")
            new.sendto(b"new", ("127.0.0.1", relay.port))
            payload, new_source = server.recvfrom(64)
            self.assertEqual(payload, b"new")
            self.assertNotEqual(old_source, new_source)
            server.sendto(b"late-old", old_source)
            server.sendto(b"current-new", new_source)
            self.assertEqual(old.recvfrom(64)[0], b"late-old")
            self.assertEqual(new.recvfrom(64)[0], b"current-new")


if __name__ == "__main__":
    unittest.main()
