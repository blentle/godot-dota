"""固定地图来源的集成回归；缺少本地原始缓存时明确跳过。"""
import unittest

from tools.classic_art.time_evidence import ROOT, build_report


@unittest.skipUnless(
    (ROOT/'references/downloads/classic-art/DotA-v6.83d-complete.w3x').is_file(),
    '需要本地固定地图及提取缓存；不下载或执行地图',
)
class TimeReportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # 实际重建并验证摘要，不把已生成的报告当作输入真值。
        cls.report = build_report()

    def test_time_calls_retain_function_ownership(self):
        calls = self.report['calls']
        self.assertEqual(self.report['counts'], {
            'SetFloatGameState': 4, 'SetTimeOfDayScale': 3,
            'SuspendTimeOfDay': 14,
        })
        owners = {c['function'] for c in calls if c['name'] == 'SetFloatGameState'}
        self.assertEqual(owners, {'HA1', 'main', 'IU2', 'BC2'})
        start = next(c for c in calls if c['function'] == 'IU2'
                     and c['name'] == 'SetTimeOfDayScale')
        self.assertIn('if r==0 then', start['conditions'])

    def test_local_time_argument_is_not_global_dataflow(self):
        entries = self.report['local_initializers']['GW1']
        argument = [e for e in entries if e['function'] == 'BC2']
        self.assertEqual(len(argument), 1)
        self.assertEqual(argument[0]['text'], 'local integer GW1=S2I(BD2)')
        self.assertIn('局部声明可遮蔽', self.report['variable_scope_warning'])

    def test_test_command_and_timer_guards_are_retained(self):
        contexts = {e['callback']: e for e in self.report['registration_contexts']}
        self.assertIn('TriggerRegisterPlayerChatEvent(t,WO,"-test",true)',
                      contexts['CI2']['context'])
        self.assertIn('TriggerRegisterTimerEvent(t,14,false)',
                      contexts['RI2']['context'])
        functions = self.report['source_functions']
        self.assertIn('set B0=true', functions['RI2']['text'])
        self.assertIn('if B0==false and(bj_isSinglePlayer and AR2())==false then',
                      functions['CI2']['text'])
        self.assertEqual(functions['AR2']['text'].count('PLAYER_SLOT_STATE_EMPTY'), 10)
        self.assertIn('return x==9', functions['AR2']['text'])

    def test_model_intervals_remain_separate_from_map_hours(self):
        models = self.report['models']
        self.assertEqual(set(models), {'human', 'nightelf', 'undead'})
        for race, model in models.items():
            with self.subTest(race=race):
                sequences = {s['name']: s['interval'] for s in model['sequences']}
                self.assertEqual(sequences['Stand'], [0, 60000])
                self.assertEqual(sequences['Stand Alternate'], [67500, 127500])
        self.assertIn('未建立实际地图时刻到模型动画帧映射', self.report['unresolved'])
