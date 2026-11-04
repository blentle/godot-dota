"""来源摘要不符时不得生成可信时间证据。"""
import tempfile
from pathlib import Path
import unittest
from tools.classic_art.time_evidence import verified_bytes


class EvidenceTests(unittest.TestCase):
    def test_reject_wrong_digest(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'source'
            path.write_bytes(b'changed')
            with self.assertRaises(ValueError):
                verified_bytes(path, '0'*64)
