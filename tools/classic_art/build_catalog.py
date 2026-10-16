"""从地图酒馆配置生成英雄外观目录；不把编辑器基础数值当作完整英雄规则。"""
import json
import re
from pathlib import Path
from read_tables import sections, slk

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'references/downloads/dota-683d-extracted/units'


def merged(pattern):
    result = {}
    for file in sorted(SOURCE.glob(pattern)):
        for code, values in sections(file).items():
            result.setdefault(code, {}).update(values)
    return result


def clean(value):
    return re.sub(r'\|c[0-9a-fA-F]{8}|\|r', '', value.strip('"'))


def resource(value, extension):
    value = value.strip('"').replace('\\', '/').lower()
    return re.sub(r'\.(mdl|mdx|blp|tga)$', '', value) + extension if value else ''


def main():
    functions = merged('*unitfunc.txt')
    strings = merged('*unitstrings.txt')
    abilities = merged('*abilityfunc.txt')
    ui = slk(SOURCE / 'unitui.slk')
    units = slk(SOURCE / 'unitabilities.slk')
    codes = list(dict.fromkeys(code for unit in functions.values()
        for code in unit.get('Sellunits', '').split(',') if len(code) == 4 and code[0].isupper()))
    assert len(codes) == 112, f'酒馆英雄数量异常：{len(codes)}'
    heroes = []
    for code in codes:
        visual, names, display = ui[code], strings[code], functions[code]
        spells = []
        for ability in units.get(code, {}).get('heroAbilList', '').split(','):
            if not ability or ability == 'Aamk':
                continue
            spell = abilities.get(ability, {})
            spells.append({'id': ability, 'icon': resource(spell.get('ResearchArt', spell.get('Art', '')), '.blp')})
        heroes.append({'id': code, 'name': clean(names.get('Name', code)),
            'proper_names': list(dict.fromkeys(clean(names.get('Propernames', '')).split(','))),
            'model': resource(visual.get('file', ''), '.mdx'),
            'icon': resource(display.get('Art', ''), '.blp'),
            'animation_tags': display.get('animProps', '').lower().split(','),
            'model_scale': float(visual.get('modelScale', 1)),
            'selection_scale': float(visual.get('scale', 1)),
            'color': [int(visual.get(channel, 255)) for channel in ['red', 'green', 'blue']],
            'abilities': spells})
    report = {'source_map_sha256': json.loads((ROOT / 'references/dota-683d-archive.json').read_text())['sha256'],
        'status': '地图配置提取目录；不表示全部模型已接入、动画已验收或英雄玩法已实现',
        'heroes': heroes}
    target = ROOT / 'game/art/classic/hero-catalog.json'
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f'已提取 {len(heroes)} 位酒馆英雄的模型、动画标签和图标映射')


if __name__ == '__main__':
    main()
