// 经典模型/贴图转换：保留原骨骼、材质与序列，生成可核对的中间数据，不生成替代美术。
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const root = path.resolve(__dirname, '../..');
const war3 = require(path.join(root, '.tools/classic-art/node_modules/war3-model'));
const {PNG} = require(path.join(root, '.tools/classic-art/node_modules/pngjs'));
const source = path.join(root, 'references/downloads/war3-original');
const target = path.join(root, 'game/art/classic');
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'references/classic-art-sources.json')));
const report = [];
function buffer(file) {
  const data = fs.readFileSync(file);
  return data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength);
}
for (const entry of manifest.files) {
  const file = path.join(source, entry.path);
  const bytes = fs.readFileSync(file);
  const blob = Buffer.concat([Buffer.from(`blob ${bytes.length}\0`), bytes]);
  const valid = entry.git_blob_sha
    ? crypto.createHash('sha1').update(blob).digest('hex') === entry.git_blob_sha
    : crypto.createHash('sha256').update(bytes).digest('hex') === entry.sha256;
  if (!valid) throw Error('原始文件摘要不符：' + entry.path);
  let output;
  if (entry.path.endsWith('.blp')) {
    const decoded = war3.decodeBLP(buffer(file));
    const pixels = war3.getBLPImageData(decoded, 0);
    const png = new PNG({width: decoded.width, height: decoded.height});
    png.data = Buffer.from(pixels.data.buffer, pixels.data.byteOffset, pixels.data.byteLength);
    output = entry.path.replace(/\.blp$/, '.png');
    const dest = path.join(target, output);
    fs.mkdirSync(path.dirname(dest), {recursive:true});
    fs.writeFileSync(dest, PNG.sync.write(png));
  } else if (entry.path.endsWith('.mdx')) {
    const model = war3.parseMDX(buffer(file));
    if (model.Version !== 800) throw Error('拒绝未经校对的非经典模型版本：' + entry.path);
    const data = {};
    for (const key of ['Version', 'Info', 'Sequences', 'GlobalSequences', 'Textures', 'Materials', 'TextureAnims', 'Geosets', 'GeosetAnims', 'Cameras', 'ParticleEmitters', 'ParticleEmitters2', 'RibbonEmitters']) data[key] = model[key];
    data.Nodes = model.Nodes.filter(Boolean);
    data.Source = entry.path;
    output = entry.path.replace(/\.mdx$/, '.json');
    const dest = path.join(target, output);
    fs.mkdirSync(path.dirname(dest), {recursive:true});
    fs.writeFileSync(dest, JSON.stringify(data, (key, value) => ArrayBuffer.isView(value) ? Array.from(value) : value));
  }
  if (output) report.push({source:entry.path, output, source_sha:entry.git_blob_sha || entry.sha256,
    ...(entry.source_map_sha256 ? {source_map_sha256:entry.source_map_sha256} : {})});
}
fs.writeFileSync(path.join(target, 'provenance.json'), JSON.stringify({repository:manifest.source, revision:manifest.revision, files:report}, null, 2) + '\n');
console.log('已转换经典原始资源：', report.length);
