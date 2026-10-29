"""校验经典资源输出的摘要、二次幂尺寸及模型/头像依赖；不替代实机视觉验收。"""
import hashlib
from collections import Counter
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'game/art/classic'


def main():
    catalog = json.loads((ART / 'hero-catalog.json').read_text())
    seen = set()
    errors = []
    for hero in catalog['heroes']:
        if hero['id'] in seen:
            errors.append('重复英雄代码：' + hero['id'])
        seen.add(hero['id'])
        pool = hero.get('proper_name_pool', [])
        expected = Counter(pool).most_common(1)[0][0] if pool else hero['name']
        if hero.get('display_name') != expected or hero['proper_names'] != list(dict.fromkeys(pool)):
            errors.append('英雄专名列表或默认显示名不一致：' + hero['id'])
        body = ART / hero['model'].replace('.mdx', '.json')
        portrait = ART / hero['model'].replace('.mdx', '_portrait.json')
        if body.exists() and not portrait.exists() and not json.loads(body.read_text()).get('Cameras'):
            errors.append('缺少原始头像相机：' + hero['id'])
        for source in [hero['model'].replace('.mdx', '.json'), hero['icon'].replace('.blp', '.png')]:
            if not (ART / source).is_file():
                errors.append('缺少英雄资源：' + source)
    assert len(seen) == 112
    pngs = list(ART.rglob('*.png'))
    for file in pngs:
        header = file.read_bytes()[:24]
        if header[:8] != b'\x89PNG\r\n\x1a\n':
            errors.append('不是 PNG：' + str(file))
            continue
        width, height = struct.unpack('>II', header[16:24])
        if not all(value > 0 and value & (value - 1) == 0 for value in [width, height]):
            errors.append(f'尺寸不是二次幂：{file} {width}×{height}')
    manifest = json.loads((ROOT / 'references/classic-art-sources.json').read_text())
    cache = ROOT / 'references/downloads/war3-original'
    for entry in manifest['files']:
        data = (cache / entry['path']).read_bytes()
        digest = (hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
                  if 'git_blob_sha' in entry else hashlib.sha256(data).hexdigest())
        if len(data) != entry['bytes'] or digest != entry.get('git_blob_sha', entry.get('sha256')):
            errors.append('来源摘要不符：' + entry['path'])
    if errors:
        raise SystemExit('\n'.join(errors))
    print(f'经典资源静态检查通过：{len(seen)} 位英雄映射，{len(pngs)} 张二次幂 PNG，{len(manifest["files"])} 项来源摘要')


if __name__ == '__main__':
    main()
