// 只读提取地图资源与配置；从不执行地图脚本，也不覆盖原始文件。
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const root = path.resolve(__dirname, '../..');
const Archive = require(path.join(root, '.tools/classic-art/node_modules/mdx-m3-viewer/dist/cjs/parsers/mpq/archive')).default;
const file = process.argv[2] || path.join(root, 'references/downloads/classic-art/DotA-v6.83d-complete.w3x');
const bytes = fs.readFileSync(file);
const archive = new Archive();
archive.load(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength), true);
const destination = path.join(root, 'references/downloads/dota-683d-extracted');
const names = ['war3map.w3i', 'war3map.wts', 'scripts/war3map.j', 'Units/UnitUI.slk', 'Units/UnitData.slk', 'Units/UnitBalance.slk', 'Units/UnitWeapons.slk', 'Units/UnitAbilities.slk', 'Units/AbilityData.slk', 'war3mapMisc.txt',
  'Units/HumanAbilityFunc.txt', 'Units/OrcAbilityFunc.txt', 'Units/NightElfAbilityFunc.txt', 'Units/UndeadAbilityFunc.txt', 'Units/NeutralAbilityFunc.txt', 'Units/CommonAbilityFunc.txt', 'Units/CampaignAbilityFunc.txt',
  'Units/HumanUnitFunc.txt', 'Units/OrcUnitFunc.txt', 'Units/NightElfUnitFunc.txt', 'Units/UndeadUnitFunc.txt', 'Units/NeutralUnitFunc.txt',
  'Units/CampaignUnitFunc.txt', 'Units/CampaignUnitStrings.txt', 'Units/OtherUnitFunc.txt', 'Units/OtherUnitStrings.txt', 'Units/HumanUnitStrings.txt', 'Units/OrcUnitStrings.txt', 'Units/NightElfUnitStrings.txt', 'Units/UndeadUnitStrings.txt', 'Units/NeutralUnitStrings.txt'];
const extracted = [];
for (const name of names) {
  const item = archive.get(name.replace(/\//g, '\\'));
  if (!item) continue;
  const data = item.bytes();
  const target = path.join(destination, name.toLowerCase());
  fs.mkdirSync(path.dirname(target), {recursive:true});
  fs.writeFileSync(target, data);
  extracted.push({path: name.toLowerCase(), bytes: data.length, sha256:crypto.createHash('sha256').update(data).digest('hex')});
}
const report = {source:'https://gaming-tools.com/warcraft-3/?ddownload=1418', sha256:crypto.createHash('sha256').update(bytes).digest('hex'),
  bytes:bytes.length, title:bytes.subarray(8,bytes.indexOf(0,8)).toString('utf8'), mpq_blocks:archive.files.length, files:extracted,
  status:'结构及所列配置可读，地图脚本未执行；尚未完成官方发行副本比对'};
// 仅提取明确的配置调用文本，不解释或执行脚本。
const script = fs.readFileSync(path.join(destination, 'scripts/war3map.j'), 'utf8');
report.ui_profile = {player_races:Array.from(script.matchAll(/SetPlayerRacePreference\(Player\((\d+)\),RACE_PREF_(\w+)\)/g), m => ({slot:Number(m[1]), race:m[2].toLowerCase()})),
  initial_time_candidates:Array.from(script.matchAll(/SetFloatGameState\(GAME_STATE_TIME_OF_DAY,([\d.]+)\)/g), m => Number(m[1])),
  note:'只读调用文本证据，未解释条件分支；训练近卫使用 nightelf 控制台'};
fs.writeFileSync(path.join(root,'references/dota-683d-archive.json'),JSON.stringify(report,null,2)+'\n');
console.log('已只读提取地图配置：',extracted.length,'；',report.title,'；',report.sha256);
