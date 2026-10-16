// 按地图优先、固定经典资源副本兜底的顺序解析外观依赖；不执行地图脚本。
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const root = path.resolve(__dirname, '../..');
const deps = path.join(root, '.tools/classic-art/node_modules');
const Archive = require(path.join(deps, 'mdx-m3-viewer/dist/cjs/parsers/mpq/archive')).default;
const war3 = require(path.join(deps, 'war3-model'));
const manifestPath = path.join(root, 'references/classic-art-sources.json');
const manifest = JSON.parse(fs.readFileSync(manifestPath));
const catalog = JSON.parse(fs.readFileSync(path.join(root, 'game/art/classic/hero-catalog.json')));
const mapPath = path.join(root, 'references/downloads/classic-art/DotA-v6.83d-complete.w3x');
const bytes = fs.readFileSync(mapPath);
const sha256 = data => crypto.createHash('sha256').update(data).digest('hex');
if (sha256(bytes) !== catalog.source_map_sha256) throw Error('地图摘要不符');
const archive = new Archive();
archive.load(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength), true);
const tree = JSON.parse(fs.readFileSync(path.join(root, 'references/downloads/war3-stock-tree.json')));
const stock = new Map(tree.tree.filter(x => x.type === 'blob' && x.path.startsWith('lowercase/')).map(x => [x.path.slice(10), x]));
const cache = path.join(root, 'references/downloads/war3-original');
const entries = new Map(manifest.files.map(x => [x.path, x]));
const visited = new Set();
const missing = [];
let pending = [];
function normalize(name) {
  return name.replace(/\\/g, '/').replace(/\.mdl$/i, '.mdx').toLowerCase();
}
function enqueue(name, optional = false) {
  name = normalize(name);
  if (!name || visited.has(name)) return;
  if (name.startsWith('/') || name.split('/').includes('..')) throw Error('不安全资源路径');
  visited.add(name);
  pending.push({name, optional});
}
async function resolve({name, optional}) {
  const target = path.join(cache, name);
  const mapped = archive.get(name.replace(/\//g, '\\'));
  let data, entry;
  if (mapped) {
    data = Buffer.from(mapped.bytes());
    entry = {path:name, bytes:data.length, sha256:sha256(data), source_map_sha256:catalog.source_map_sha256};
  } else if (stock.has(name)) {
    const item = stock.get(name);
    entry = {path:name, bytes:item.size, git_blob_sha:item.sha,
      url:`https://raw.githubusercontent.com/WarRaft/War3.mpq/${manifest.revision}/${item.path}`};
    if (fs.existsSync(target)) data = fs.readFileSync(target);
    const valid = value => value && value.length === item.size && crypto.createHash('sha1').update(Buffer.concat([Buffer.from(`blob ${value.length}\0`),value])).digest('hex') === item.sha;
    if (!valid(data)) {
      for (let attempt = 0; attempt < 3; attempt++) {
        try {
          const response = await fetch(entry.url, {signal:AbortSignal.timeout(90000)});
          if (!response.ok) throw Error(`下载失败 ${response.status}: ${name}`);
          data = Buffer.from(await response.arrayBuffer());
          break;
        } catch (error) {
          if (attempt === 2) throw error;
          console.log('重试资源：', name);
        }
      }
    }
    if (!valid(data)) throw Error('资源摘要不符：' + name);
  } else {
    missing.push({path:name, optional});
    return;
  }
  fs.mkdirSync(path.dirname(target), {recursive:true});
  fs.writeFileSync(target, data);
  entries.set(name, entry);
  if (name.endsWith('.mdx')) {
    const model = war3.parseMDX(data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength));
    if (model.Version !== 800) throw Error('非经典格式：' + name);
    for (const texture of model.Textures) if (texture.Image) enqueue(texture.Image);
  }
}
async function main() {
  for (const hero of catalog.heroes) {
    enqueue(hero.model);
    enqueue(hero.model.replace(/\.mdx$/, '_portrait.mdx'), true);
    enqueue(hero.icon);
    for (const ability of hero.abilities) enqueue(ability.icon);
    for (const icon of [hero.icon, ...hero.abilities.map(x => x.icon)]) {
      if (icon.includes('/commandbuttons/btn')) enqueue(icon.replace('/commandbuttons/btn','/commandbuttonsdisabled/disbtn'));
    }
  }
  let completed = 0;
  while (pending.length) {
    const batch = pending.splice(0, 8);
    await Promise.all(batch.map(resolve));
    completed += batch.length;
    manifest.files = Array.from(entries.values()).sort((a,b) => a.path.localeCompare(b.path));
    fs.writeFileSync(manifestPath, JSON.stringify(manifest,null,2)+'\n');
    console.log(`已解析 ${completed} 项，待解析 ${pending.length} 项`);
  }
  const report = {map_sha256:catalog.source_map_sha256, requested:visited.size, resolved:visited.size-missing.length, missing};
  fs.writeFileSync(path.join(root,'references/hero-art-resolution.json'),JSON.stringify(report,null,2)+'\n');
  console.log('外观依赖解析完成；缺失项：', missing.length);
}
main().catch(error => {console.error(error); process.exitCode=1;});
