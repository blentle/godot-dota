"""从已记录摘要的源文件生成时间证据；只读扫描，不运行 JASS。"""
import bisect
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
from tools.classic_art.time_calls import extract_calls, mask_source

ROOT = Path(__file__).resolve().parents[2]


def verified_bytes(path, expected):
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != expected:
        raise ValueError('来源摘要不符：'+str(path))
    return data


def build_report():
    archive = json.loads((ROOT/'references/dota-683d-archive.json').read_text())
    verified_bytes(ROOT/'references/downloads/classic-art/DotA-v6.83d-complete.w3x', archive['sha256'])
    files = {entry['path']: entry for entry in archive['files']}
    extracted = ROOT/'references/downloads/dota-683d-extracted'
    script = verified_bytes(extracted/'scripts/war3map.j', files['scripts/war3map.j']['sha256']).decode('utf-8-sig')
    misc = verified_bytes(extracted/'war3mapmisc.txt', files['war3mapmisc.txt']['sha256']).decode('utf-8-sig')
    calls = extract_calls(script)
    original, masked = mask_source(script)
    starts = [0]+[m.end() for m in re.finditer('\n', masked)]
    declarations = [(m.start(), m[1]) for m in re.finditer(r'(?m)^function\s+(\w+)\s+takes\b', masked)]
    positions = [p for p, _ in declarations]

    def location(match):
        index = bisect.bisect_right(positions, match.start())-1
        return {'line': bisect.bisect_right(starts, match.start()),
                'function': declarations[index][1] if index >= 0 else '全局',
                'text': original[match.start():match.end()]}

    functions = {}
    for name in sorted({call['function'] for call in calls}):
        pattern = r'\b(?:call\s+'+re.escape(name)+r'\s*\(|function\s+'+re.escape(name)+r'\b(?!\s+takes))'
        functions[name] = {'direct_references': [location(m) for m in re.finditer(pattern, masked)],
                           'status': '直接引用线索；尚未证明运行时可达或模式/技能含义'}
    variables = sorted({v for call in calls for v in re.findall(r'\b[A-Z]\w*\b', call['text'].split('(', 1)[-1])
                        if v not in ['GAME_STATE_TIME_OF_DAY']})
    assignments = {name: [location(m) for m in re.finditer(r'\bset\s+'+re.escape(name)+r'\s*=[^\n]*', masked)]
                   for name in variables}
    # 只扩展一层直接入口，不递归猜测完整触发链；复用相同词法条件扫描。
    entry_names = sorted(set(functions) | {'VU2', 'BK2'})
    entry_calls = extract_calls(script, targets=entry_names)
    initializers = {name: [location(m) for m in re.finditer(r'\blocal\s+\w+\s+'+re.escape(name)+r'\s*=[^\n]*', masked)]
                    for name in variables}
    counts = dict(Counter(call['name'] for call in calls))
    expected = {'SetFloatGameState': 4, 'SetTimeOfDayScale': 3, 'SuspendTimeOfDay': 14}
    if counts != expected:
        raise ValueError('固定来源调用数变化，须人工核对：'+str(counts))
    day = re.search(r'(?m)^DayLength=([^\r\n]+)', misc)
    models = {}
    for race in ['human', 'nightelf', 'undead']:
        path = ROOT/f'game/art/classic/ui/console/{race}/{race}ui-timeindicator.json'
        data = path.read_bytes()
        model = json.loads(data)
        models[race] = {'path': str(path.relative_to(ROOT)), 'sha256': hashlib.sha256(data).hexdigest(),
                        'sequences': [{'name': s['Name'], 'interval': s['Interval']} for s in model['Sequences']],
                        'texture_animations': model.get('TextureAnims', []),
                        'textures': model['Textures']}
    return {'map_sha256': archive['sha256'], 'extracted_sources': {name: files[name]['sha256'] for name in ['scripts/war3map.j', 'war3mapmisc.txt']},
            'line_numbering': 'CRLF/CR 正规化为 LF 后的 1 起始行号',
            'day_length_config': day[1] if day else None, 'counts': counts, 'calls': calls,
            'functions': functions, 'direct_entry_calls': entry_calls,
            'entry_scope': '时间函数及 VU2/BK2 注册函数的一层直接调用；不证明完整可达性',
            'variable_assignments': assignments,
            'local_initializers': initializers,
            'variable_scope_warning': '按标识符收集，不代表同一变量；局部声明可遮蔽同名全局变量，须结合函数归属阅读',
            'models': models,
            'unresolved': ['动态调用未建立完整调用图；直接引用不证明可达', '条件栈仅为语法上下文，不求解变量值',
                           '未验证引擎时间倍率语义及实际昼夜周期', '未建立实际地图时刻到模型动画帧映射',
                           '未执行 JASS，未将混淆函数猜测为模式或技能名称']}


def main():
    report = build_report()
    target = ROOT/'references/classic-time-evidence.json'
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    print('时间静态证据已生成：', report['counts'])


if __name__ == '__main__':
    main()
