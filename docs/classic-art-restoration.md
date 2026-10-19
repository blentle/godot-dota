# 经典 HUD 与英雄外观还原

## 当前基准

用户已确认以 Warcraft III 1.26 / DotA 6.83d 实机画面为准。固定 1024×768；命令卡为四列三行，物品栏为两列三行，英雄头像使用独立模型和原始相机。此前四技能横排、物品放技能下方的场景保留为组件测试夹具，不再作为视觉目标。

当前实现采用固定提交的经典资源镜像及可读的 6.83d 地图候选。地图 SHA-256 为 `326d7ea8fb2bf20bd540259ebc3e80d398cf1be79fe1827691927c9008107495`，未执行地图脚本；尚未完成官方发行副本及 Warcraft III 1.26 安装资源逐项比对。因此不宣称完整还原或达到 95%。

## 运行入口

```sh
.tools/Godot.app/Contents/MacOS/Godot --path game -- --war3-training
.tools/Godot.app/Contents/MacOS/Godot --path game -- --classic-gallery
```

第一条启动原始皮肤训练场。第二条为美术校对入口，PageUp / PageDown 切换地图英雄外观。切换不会改变训练角色规则，不能把它视为完整英雄选人或正式英雄技能实现。无参数启动也进入新的原始皮肤训练场；`--legacy-client` 保留旧选人入口。联机入口及 `--war3-hud` 组件夹具保留。

## 资源与可复现转换

- 来源、固定提交、字节数与 Git blob SHA：`references/classic-art-sources.json`。
- 地图结构、提取配置及 SHA-256：`references/dota-683d-archive.json`。
- 地图酒馆提取出的 112 位英雄映射：`game/art/classic/hero-catalog.json`。同时保留模型、图标、缩放、颜色和动画标签，不将编辑器基础数值误作完整英雄规则。
- 模型及依赖解析报告：`references/hero-art-resolution.json`；输出逐项摘要见 `game/art/classic/provenance.json`。
- 原始缓存位于被忽略的 `references/downloads`。第三方代码只安装到 `.tools/classic-art/node_modules`；转换、解析与运行时代码位于正常受检源码目录。

工具依赖及传递依赖摘要固定在 `tools/classic_art/package.json`、`package-lock.json`。将这两个文件复制到 `.tools/classic-art`，在该目录运行 `npm ci --ignore-scripts`，然后回到仓库根目录运行：

```sh
python3 tools/fetch_classic_art.py
node tools/classic_art/read_map.cjs
python3 tools/classic_art/build_catalog.py
node tools/classic_art/fetch_heroes.cjs
node tools/classic_art/convert.cjs
python3 tools/classic_art/compose_console.py
python3 tools/classic_art/prepare_panels.py
python3 tools/classic_art/prepare_races.py
```

首次处理地图内资源时，先运行 `read_map`、`build_catalog`、`fetch_heroes`，再校验完整资源清单。Pillow 是两个拼图工具的依赖。资源镜像完整树缓存须与清单的固定提交一致。详见目录内 NOTICE；镜像代码许可证不能替代 Blizzard 美术及地图作者权利。

## 场景与职责

```text
retail_hud.tscn / retail_hud.gd
├─ Console、Clock、TopMenu0..3、Resources
├─ Multiboard / multiboard.gd
├─ TeamPortraits / portrait_cell.gd
├─ Minimap/MapTexture / minimap_controller.gd
├─ HeroPanel
│  ├─ Portrait / portrait_view.gd / SubViewport
│  ├─ Health、Mana、Experience / clipped_bar.gd
│  ├─ Attributes、Damage、Armor
│  ├─ Command0..3、Attack、Learn
│  ├─ Skill0..3 / icon_button.gd
│  └─ Item0..5 / icon_button.gd
├─ Tooltip / tooltip.gd
└─ FloatingTextPool / floating_text_pool.gd
```

节点布局在静态 `.tscn` 中；Godot 4 使用 `offset_*`、`position`、`size`，不写 Godot 3 的 `rect_position` / `rect_size` 属性。运行脚本只刷新表现和发出命令。规则入口继续验证施法、升级、买卖条件。

模型模块拆为原始动画轨道采样、材质、网格蒙皮、模型视图及头像相机。支持经典 v800、最多八权重矩阵组、多层材质、动作和全局时钟；地图 `animProps=alternate` 已用于宙斯，模型缩放为地图记录的 1.3。动作切换不能退回普通山丘形态。

## 1024×768 坐标

| 元素 | 左上角 | 尺寸 / 间距 |
|---|---|---|
| 原始 Console | 0,0 | 1024×1024 POT 图，画布裁到 768；分块位置取原 FDF |
| 顶栏四按钮 | 3+109×i,2 | 109×28 |
| 昼夜盘 | 435,-7 | 154×77 |
| 资源区 | 591,0 | 433×28 |
| 自己的英雄头像列 | 4,48 | 48×48，纵向间距 52 |
| 计分板开关 | 884,35 | 128×28 |
| 小地图框内视口 | 13,585 | 176×176 |
| 动态头像 | 270,625 | 108×103；独立 128×128 视口 |
| 血量 / 魔法数字 | 270,729 / 270,748 | 108×16 |
| 英雄名 | 396,608 | 230×20 |
| 经验条 | 396,630 | 230×10，裁剪宽度 |
| 等级 / 职业 | 397,640 | 230×18 |
| 攻击 / 护甲图标 | 401,664 / 401,710 | 40×40 |
| 三属性区 | 531,658 | 100×86，纵向排列 |
| 指令第一行 | 790+56×i,596 | 50×50，共四格 |
| 攻击 / 加点 | 790,652 / 958,652 | 50×50 |
| 技能行 | 790+56×i,710 | 50×50，共四格 |
| 六格物品 | 659+50×列,623+49×行 | 42×42，两列三行 |
| Tooltip 默认位置 | 688,368 | 320×160；出现时随鼠标避开屏幕边缘 |

这些是当前实现坐标；原始 FDF 定位与对照截图验收应分开记录，不把所有表内数值称为已完成逐像素校准。

## 渲染和状态

PNG 无 mipmap；UI 节点最近邻过滤、禁止重复，关闭 2D/3D MSAA、TAA、屏幕抗锯齿。原始非整尺寸区域放在二次幂画布，通过 AtlasTexture 读取。菜单、提示框和边框均使用原始纹理，不使用圆角 Theme 或 StyleBoxFlat。

保留独立正常、hover 和 DISBTN 层。灰图来自原始预制资源；没有使用 shader 或运行时灰度替代。原版英雄头像下方以血蓝数字为主，旧夹具的长血蓝条在原生布局隐藏；经验条仍为 TextureRect + clip_contents 裁剪。字体沿用关闭平滑的像素渲染配置，但字体字形与原版逐字比对尚未验收。

## 尚未通过的视觉验收

- 地形、树、塔和建筑仍为训练占位美术；原版地图地形尚未接入。
- 全部英雄逐一对照实机的动作、体型、头像、队色及特效尚未验收。纹理平移、Geoset 颜色/透明度及头像相机轨道已补齐，详见 [表面与头像时间轨](classic-material-animation.md)；粒子、飘带、UV 旋转及部分模型节点标志仍需补齐。
- 已生成暗夜精灵、亡灵、人族控制台和菜单状态。地图脚本记录近卫玩家为 nightelf、天灾玩家为 undead；训练场默认改用暗夜精灵。亡灵皮肤的完整实机截图对照、昼夜盘实时变化、原生选店行为和完整十人计分板内容尚未完成。
- 原始地图技能映射已提取，但训练三技能仍是开发规则；属性未知处保留空值，不伪造正式英雄数值。
- 仅 macOS 实机检查；Windows、Linux 未验收。

## 本次验证

- 112 位英雄映射及全部必需本体、图标、贴图依赖静态检查通过；10 个缺少独立头像文件的条目均在本体保留相机。
- 214 个去重后的英雄本体与头像模型通过骨骼、材质构建及多动作推进冒烟。加载通过不是逐像素外观验收。
- 水晶室女、屠夫、冰魂、宙斯的外观切换与头像同步回归通过，切换不修改训练生命、魔法、攻击和角色规则。
- 原有工程统一规则及场景回归通过；命令卡加点、商店 B 键、交易及输入遮挡回归保留。
- 模型材质的 modulate2x 目前按乘色近似，粒子、飘带与部分 UV 动画仍是明确缺口。

- 2026-10-18：补齐模型纹理平移、分部件颜色/透明度、相机位置/目标/滚转轨道；新增真实模型时间点回归和确定时间点实机截图工具。完整验收边界见 [本轮说明](classic-material-animation.md)。

- 2026-10-19：接入原始 ParticleEmitter2 基础运行时，含固定步长/对象池、连续与喷发、头尾图集和分段颜色。影魔 macOS 实机检查完成；旧式发射器、飘带和精确视觉验收仍未完成，详见 [粒子说明](classic-particles.md)。
