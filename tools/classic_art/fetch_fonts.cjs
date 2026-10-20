// 固定经典资源副本中的字体：下载、核验 Git blob，保留原始文件名与来源。
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const {execFileSync} = require('child_process');
const root = path.resolve(__dirname, '../..');
const manifestPath = path.join(root, 'references/classic-art-sources.json');
const manifest = JSON.parse(fs.readFileSync(manifestPath));
const tree = JSON.parse(fs.readFileSync(path.join(root, 'references/downloads/war3-stock-tree.json')));
const fonts = tree.tree.filter(x => x.path.startsWith('extract/Fonts/') && /\.ttf$/i.test(x.path));
for (const item of fonts) {
  const relative = 'fonts/'+path.basename(item.path).toLowerCase();
  const target = path.join(root, 'references/downloads/war3-original', relative);
  const url = `https://raw.githubusercontent.com/WarRaft/War3.mpq/${manifest.revision}/${item.path}`;
  const valid = bytes => bytes && bytes.length === item.size && crypto.createHash('sha1')
    .update(Buffer.concat([Buffer.from(`blob ${bytes.length}\0`), bytes])).digest('hex') === item.sha;
  let bytes = fs.existsSync(target) ? fs.readFileSync(target) : null;
  if (!valid(bytes)) bytes = execFileSync('curl', ['--fail', '--silent', '--show-error', '--location',
    '--retry', '2', '--max-time', '90', url], {maxBuffer:16*1024*1024});
  if (!valid(bytes)) throw Error('字体摘要不符：'+relative);
  fs.mkdirSync(path.dirname(target), {recursive:true});
  fs.writeFileSync(target, bytes);
  const entry = {path:relative, bytes:bytes.length, git_blob_sha:item.sha, url};
  const index = manifest.files.findIndex(x => x.path === relative);
  if (index < 0) manifest.files.push(entry); else manifest.files[index] = entry;
  console.log('字体来源已核验：'+relative);
}
fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2)+'\n');
