"""统计已导入原始模型的粒子覆盖，明确旧发射器、飘带和精确混合仍有缺口。"""
from collections import Counter
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'game/art/classic'


def main():
    counts = Counter()
    filters = Counter()
    for path in sorted(ART.rglob('*.json')):
        model = json.loads(path.read_text())
        if not isinstance(model, dict) or model.get('Version') != 800:
            continue
        emitters = model.get('ParticleEmitters2', [])
        counts['models_with_particle2'] += bool(emitters)
        counts['particle2_emitters'] += len(emitters)
        counts['legacy_emitters_not_implemented'] += len(model.get('ParticleEmitters', []))
        counts['ribbon_emitters_not_implemented'] += len(model.get('RibbonEmitters', []))
        for entry in emitters:
            assert entry['FrameFlags'] in [1, 2, 3], f'未知头尾类型：{path}'
            assert 0 <= entry['TextureID'] < len(model['Textures']), f'无效纹理编号：{path}'
            assert entry['ReplaceableId'] in [0, 1, 2], f'未知可替换纹理：{path}'
            filters[str(entry['FilterMode'])] += 1
            counts['squirt_emitters'] += entry['Squirt']
            counts['model_space_emitters'] += bool(entry['Flags'] & 524288)
            counts['xy_quad_emitters'] += bool(entry['Flags'] & 1048576)
            counts['tail_emitters'] += bool(entry['FrameFlags'] & 2)
            counts['atlas_emitters'] += entry['Rows'] * entry['Columns'] > 1
    report = {'source_revision': json.loads((ART / 'provenance.json').read_text())['revision'],
        'source_map_sha256': json.loads((ART / 'hero-catalog.json').read_text())['source_map_sha256'],
        'counts': dict(counts), 'filter_modes': dict(sorted(filters.items())),
        'status': '配置可读及基础表现已接入，不代表原版逐帧或像素验收',
        'limits': {'particles_per_model': 512, 'simulation_hz': 60, 'max_catchup_seconds': 2},
        'remaining': ['旧 ParticleEmitter、RibbonEmitter 尚未实现', 'modulate2x 仍以乘色近似',
                      '发射节点的帧内运动插值及部分节点标志未完成', '三轴非均匀缩放、拖尾 UV 方向与原版精确混合待逐模型核对',
                      '仅 macOS 实机检查，Windows、Linux 尚未验收']}
    target = ROOT / 'references/classic-particle-coverage.json'
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(report['counts'], ensure_ascii=False))


if __name__ == '__main__':
    main()
