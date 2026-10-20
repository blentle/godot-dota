"""打包已核验的原始西文与简体字形候选，保留出处，不依赖系统字体。"""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]


def main():
    manifest = json.loads((ROOT / 'references/classic-art-sources.json').read_text())
    entries = {x['path']: x for x in manifest['files']}
    target = ROOT / 'game/art/classic/fonts'
    target.mkdir(exist_ok=True)
    report = []
    for name in ['frizqt__.ttf', 'dfst-m3u.ttf']:
        source = ROOT / 'references/downloads/war3-original/fonts' / name
        data = source.read_bytes()
        entry = entries['fonts/' + name]
        digest = hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
        if digest != entry['git_blob_sha'] or len(data) != entry['bytes']:
            raise ValueError('字体来源摘要不符：'+name)
        shutil.copyfile(source, target / name)
        report.append({'file': name, 'git_blob_sha': digest, 'url': entry['url']})
    (target / 'sources.json').write_text(json.dumps({'revision': manifest['revision'],
        'status': '固定资源副本原始字体；简体语言包对应关系尚未实机验收',
        'files': report}, ensure_ascii=False, indent=2)+'\n')


if __name__ == '__main__':
    main()
