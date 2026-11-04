"""比较原始种族时钟的取景、序列与贴图依赖，不推导游戏时间。"""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'game/art/classic'


def main():
    report = {}
    for race in ['human', 'nightelf', 'undead']:
        path = ART / f'ui/console/{race}/{race}ui-timeindicator.json'
        model = json.loads(path.read_text())
        assert model['Source'] == f'ui/console/{race}/{race}ui-timeindicator.mdx'
        for texture in model['Textures']:
            if texture['Image']:
                image = texture['Image'].replace('\\', '/').lower().replace('.blp', '.png')
                assert (ART / image).is_file(), image
        vertices = [g['Vertices'][i:i+3] for g in model['Geosets'] for i in range(0, len(g['Vertices']), 3)]
        report[race] = {'source': model['Source'], 'bounds': [[min(v[i] for v in vertices), max(v[i] for v in vertices)] for i in range(3)],
                        'sequences': [{'name': s['Name'], 'interval': s['Interval']} for s in model['Sequences']],
                        'textures': [t['Image'] for t in model['Textures']]}
    (ROOT / 'references/classic-clock-coverage.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    print('三种族时钟资源检查通过；范围一致：', len({str(v['bounds']) for v in report.values()}) == 1)


if __name__ == '__main__':
    main()
