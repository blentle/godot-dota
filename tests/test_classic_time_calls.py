"""时间证据扫描必须区分代码、注释、字符串和条件分支。"""
import unittest
from tools.classic_art.time_calls import extract_calls


class TimeCallsTests(unittest.TestCase):
    def test_lexical_context(self):
        source = ('function F takes nothing returns nothing\r\n'
                  '// call SuspendTimeOfDay(true)\r'
                  'call Print("SetTimeOfDayScale(9) // \\\" ")\n'
                  'if A then\nif B then\ncall SuspendTimeOfDay(true)\n'
                  'else\ncall SetTimeOfDayScale(0.5)\nendif\nendif\nendfunction')
        calls = extract_calls(source)
        self.assertEqual([x['name'] for x in calls], ['SuspendTimeOfDay', 'SetTimeOfDayScale'])
        self.assertEqual(calls[0]['function'], 'F')
        self.assertEqual(calls[0]['line'], 6)
        self.assertEqual(calls[0]['conditions'], ['if A then', 'if B then'])
        self.assertEqual(calls[1]['conditions'], ['if A then', 'if B then → else'])

    def test_exact_names_and_multiline(self):
        calls = extract_calls('call FakeSetTimeOfDayScale(2)\ncall SetTimeOfDayScale(\n0.625\n)')
        self.assertEqual(len(calls), 1)
        self.assertIn('0.625', calls[0]['text'])

    def test_unclosed_string_rejected(self):
        with self.assertRaises(ValueError):
            extract_calls('call Print("missing)')

    def test_requested_function_calls_keep_conditions(self):
        source = ('function main takes nothing returns nothing\n'
                  'if bj_isSinglePlayer and Allowed() then\n'
                  'call RegisterClock()\nendif\nendfunction')
        calls = extract_calls(source, targets=('RegisterClock',))
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0]['conditions'], ['if bj_isSinglePlayer and Allowed() then'])
        self.assertEqual(extract_calls(source, targets=()), [])
