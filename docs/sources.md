# 素材与参考来源台账

检索日期：2026-10-06。用户授权从互联网自行查找素材。

## 6.83d 地图候选

- [GetDota.info](https://getdota.info/)：站点自述为非官方备份，页面有 2015-06-10 的 6.83d 条目。[压缩包链接](https://getdota.info/maps/DotA%20v6.83d.zip)。作为首个待核验候选，不把镜像域名当作官方真实性证明。
- [Epic War 的 6.83d RU](https://www.epicwar.com/maps/269493/)：俄文候选页面，标注 112 名英雄、10 人、128×128 地图。仅用于交叉检查，不能用页面描述直接填入已验证英雄名单，也不与英文候选混为同一内容包。
- [Epic War 257803](https://www.epicwar.com/maps/257803/)：搜索标题看似无语言后缀，打开后正文明确为菲律宾语翻译，已排除为英文基准，避免只凭文件名误判。
- [Hive 2020 年地图讨论](https://www.hiveworkshop.com/threads/extracting-and-importing-dota-models.325909/)：页面列有 6.83d 地图附件，并讨论缺失 MPQ listfile 的情况。尚未取得附件或验证其版本，可作为后续地图结构研究线索。

下载件置于 `references/downloads/`，不进入 Godot 资源目录或发布包。检查压缩包成员、实际地图标题与哈希后再解析；候选未完成独立交叉校验前不更新 manifest 的已验证字段。只读取地图数据，不执行下载的程序或地图脚本。

实际下载结果：GetDota.info 返回 12,644,945 字节，文件头含 HTML 与损坏的 ZIP 字节，Python ZIP 校验失败，已标记 `rejected_not_zip`，未导入游戏。哈希与检查结果保存在 `references/map-candidate.json`。该链接不能作为当前可信地图基准，需更换来源继续核对。

## UI / 操作参考候选

- [DotA 6.83d — Alchemist Gameplay](https://www.youtube.com/watch?v=OP65UlczDpo)
- [DotA 6.83d — Invoker Gameplay](https://www.youtube.com/watch?v=rwGf3pm4CGo)

搜索已定位到标题标注该版本的录像，尚未逐帧核对，也未建立固定分辨率截图基准。下一步核对画面版本、HUD 皮肤、语言、比例和热键；旧版本或不同皮肤画面不得混用为 95% 评分基准。

## 场景素材候选

| 来源 | 作者/页面许可标注 | 可用方向 | 当前状态 |
|---|---|---|---|
| [Fantasy Town Kit](https://kenney.nl/assets/fantasy-town-kit) | Kenney，CC0，160 个 3D 文件 | 开发期建筑、塔与场景组合 | 已查看来源页，未下载/导入 |
| [KayKit Medieval Builder](https://kaylousberg.itch.io/kaykit-medieval-builder-pack) | Kay Lousberg，CC0 | 开发期道路、河岸与建筑，提供 GLTF 等格式 | 已查看来源页；legacy 包，不再更新 |
| [Hive Workshop 资源库](https://hiveworkshop.com/resources_new/models/) | 各作者与各资源不同 | 查找更接近经典风格的模型 | 检索入口，未选定具体资源 |

CC0 候选的美术风格与 Warcraft III 不同，不作为最终 95% 视觉验收的替代标准。具体下载后保留包内许可与作者信息。Hive 的地图模组资源不自动视为可在独立 Godot 游戏中发布；按具体作者声明记录使用范围。

## 尚未找到的完整资源

尚无已确认可整包用于独立客户端的 Warcraft III 英雄模型、原版 HUD、头像、技能图标与音效全集。后续按英雄/界面区域建台账，采用可用的作者资源或重绘/重建；不把“网页有下载”记作“正式资源已就绪”。
