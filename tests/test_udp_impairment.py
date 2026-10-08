"""确定性故障策略测试，避免无效配置和名义丢包但实际未触发。"""

import unittest

from tools.udp_impairment import DatagramPolicy


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


if __name__ == "__main__":
    unittest.main()
