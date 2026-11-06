"""只读提取地图防御塔外观；不把训练塔当作原版等级规则。"""
import hashlib
import json
from pathlib import Path
from tools.classic_art.read_tables import sections, slk

ROOT = Path(__file__).resolve().parents[2]


def main():
    archive = json.loads((ROOT/'references/dota-683d-archive.json').read_text())
    entries = {e['path']: e for e in archive['files']}
    source = ROOT/'references/downloads/dota-683d-extracted'
    paths = ['units/unitui.slk', 'units/nightelfunitfunc.txt', 'units/undeadunitfunc.txt']
    for path in paths:
        if hashlib.sha256((source/path).read_bytes()).hexdigest() != entries[path]['sha256']:
            raise ValueError('原始配置摘要不符：'+path)
    ui = slk(source/paths[0])
    functions = sections(source/paths[1]) | sections(source/paths[2])
    towers = []
    for team, codes in enumerate([['e00R', 'e011', 'e00S', 'e019'],
                                 ['u00M', 'u00D', 'u00N', 'u00T']]):
        for level, code in enumerate(codes, 1):
            row = ui[code]
            towers.append({'id': code, 'team': team, 'level': level,
                           'model': row['file'].replace('\\', '/').lower()+'.json',
                           'model_scale': float(row['modelScale']),
                           'animation_tags': functions[code].get('Animprops', '').lower().split(',')
                           if functions[code].get('Animprops') else [],
                           'color': [int(row.get(c, 255)) for c in ['red', 'green', 'blue']]})
    report = {'source_map_sha256': archive['sha256'],
              'sources': {p: entries[p]['sha256'] for p in paths},
              'status': '原始外观配置；训练场只使用一级外观，不实现原版建筑等级规则',
              'towers': towers}
    (ROOT/'game/art/classic/tower-catalog.json').write_text(
        json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    print('已核对八项防御塔外观配置')
    bases = []
    for team, code in enumerate(['etol', 'unpl']):
        row = ui[code]
        bases.append({'id': code, 'team': team,
                      'model': row['file'].replace('\\', '/').lower()+'.json',
                      'model_scale': float(row['modelScale']),
                      'color': [int(row.get(c, 255)) for c in ['red', 'green', 'blue']],
                      'animation_tags': functions[code].get('Animprops', '').lower().split(',')
                      if functions[code].get('Animprops') else []})
    base_report = {'source_map_sha256': archive['sha256'], 'sources': report['sources'],
                   'status': '原始基地外观；不表示训练基地规则或死亡动画已还原', 'bases': bases}
    (ROOT/'game/art/classic/base-catalog.json').write_text(
        json.dumps(base_report, ensure_ascii=False, indent=2)+'\n')
    print('已核对两项基地外观配置')


if __name__ == '__main__':
    main()
