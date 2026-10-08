"""验证网络回归工具的参数边界与失败清理，避免测试通过但未执行截图。"""

import importlib.util
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

PATH = Path(__file__).resolve().parents[1] / "tools/test_network_pair.py"
SPEC = importlib.util.spec_from_file_location("network_runner", PATH)
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class NetworkRunnerTests(unittest.TestCase):
    def test_capture_argument_is_user_argument(self):
        command = runner._client_command(["godot", "--headless", "--path", "game"],
                                         27883, "network_scene", Path("/tmp/review"))
        self.assertNotIn("--headless", command)
        self.assertGreater(command.index(f"--output-dir={Path('/tmp/review').resolve()}"), command.index("--"))

    def test_failed_first_client_stops_second_client(self):
        first = Mock()
        first.wait.return_value = 1
        first.poll.return_value = 1
        second = Mock()
        second.poll.return_value = None
        second.wait.return_value = 0
        with patch.object(runner.subprocess, "Popen", side_effect=[first, second]):
            with self.assertRaises(RuntimeError):
                runner._run_concurrent(["godot"], 27883)
        second.terminate.assert_called_once()
        second.wait.assert_called_once()

    def test_script_error_overrides_success_marker(self):
        result = Mock(returncode=0, stdout="NETWORK_CLIENT_PASS\nSCRIPT ERROR: failure", stderr="")
        with patch.object(runner.subprocess, "run", return_value=result), patch("builtins.print"):
            with self.assertRaises(RuntimeError):
                runner._run_client(["godot"], 27883, "network_client", 2, "NETWORK_CLIENT_PASS", "测试")


if __name__ == "__main__":
    unittest.main()
