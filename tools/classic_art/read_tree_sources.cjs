// 只读提取地图树木来源线索；不执行脚本，不把基础对象默认值当成地图覆盖。
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const root = path.resolve(__dirname, '../..');
const parsers = path.join(root, '.tools/classic-art/node_modules/mdx-m3-viewer/dist/cjs/parsers');
const Archive = require(path.join(parsers, 'mpq/archive')).default;
const Doodads = require(path.join(parsers, 'w3x/doo/file')).default;
const Objects = require(path.join(parsers, 'w3x/w3u/file')).default;
const digest = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const expected = JSON.parse(fs.readFileSync(path.join(root, 'references/dota-683d-archive.json')));
const bytes = fs.readFileSync(path.join(root, 'references/downloads/classic-art/DotA-v6.83d-complete.w3x'));
if (digest(bytes) !== expected.sha256) throw Error('地图摘要不符');
const archive = new Archive();
archive.load(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength), true);
const sources = {};
function read(name) {
  const entry = archive.get(name);
  if (!entry) throw Error('缺少地图原始文件：' + name);
  const data = entry.bytes();
  sources[name] = {bytes: data.length, sha256: digest(data)};
  return data;
}
const placed = new Doodads();
placed.load(read('war3map.doo'), 26);
const objects = new Objects();
objects.load(read('war3map.w3b'));
const counts = {};
for (const entry of placed.doodads) counts[entry.id] = (counts[entry.id] || 0) + 1;
const trees = ['ATtr', 'NTtw'];
const report = {
  source_map_sha256: expected.sha256,
  sources,
  placed_counts: counts,
  tree_candidates: trees.map(id => ({id, placed: counts[id] || 0,
    variations: [...new Set(placed.doodads.filter(e => e.id === id).map(e => e.variation))].sort((a,b) => a-b)})),
  original_overrides: objects.originalTable.objects,
  custom_overrides: objects.customTable.objects,
  status: '地图放置与对象覆盖的静态证据；尚未解析经典基础对象表，不代表完整树木目录',
  unresolved: ['ATtr/NTtw 的基础模型及替换纹理需与固定经典对象表合并',
    '未将自定义对象与运行时生成树木的脚本调用关联',
    '尚未改变训练树位、模型、障碍或可破坏规则'],
};
fs.writeFileSync(path.join(root, 'references/classic-tree-sources.json'), JSON.stringify(report, null, 2)+'\n');
console.log('地图树木来源已提取：', report.tree_candidates);
