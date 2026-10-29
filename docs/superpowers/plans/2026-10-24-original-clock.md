# 原始顶部时钟实施计划

> 执行要求：使用 superpowers:executing-plans 按任务实施；如用户另选子代理方式，则使用 superpowers:subagent-driven-development。以下复选框用于记录进度。

**目标：** 用原始模型替换顶部静态白色太阳盘，完成可重复的动画校对与暂停处理。

**架构：** 复用现有 `model_view.gd`，用专用 TextureRect/SubViewport 组件隔离时钟世界。场景描述布局与取景，脚本只处理绑定、时间采样和暂停。先独立验证，再接入 HUD。

**技术栈：** Godot 4.7.2、GDScript、现有 MDX v800 中间数据与原始纹理；不引入依赖。

**设计依据：** `docs/plans/2026-10-24-original-clock-design.md`，用户已批准。

## 全局约束

- 固定 1024×768；Clock 区域保持 (435,-7)–(589,70)。
- 最近邻采样、关闭抗锯齿、独立透明 3D 视口，内部使用 256×128 二次幂分辨率。
- 每个自有源文件不超过 500 行；文档、注释及测试说明使用中文。
- 仅改变表现，不写入生命、魔法、冷却、金币或服务器状态，不新增昼夜玩法。
- 原始时间映射、种族一致性及精确混合未通过比较时必须保留未验收说明。

## 重点风险与对应验证

1. 模型没有相机，错误视角可能得到空白或背面：任务一的图形截图必须显示有效盘面，不能仅凭加载成功通过。
2. 透明背景或材质造成白块：任务一检查背景透明及多个时间点的实际像素。
3. 模型框与静态框重复：任务二检查 HUD 只存在一套可见边框。
4. 暂停、恢复或重绑遗留旧状态：任务一验证暂停不推进、恢复可推进、重复绑定不累积子节点。
5. 仅近卫验证却覆盖其他种族：任务二明确限制当前已验证种族，保留其他种族的既有路径及说明。

## 任务一：独立时钟组件及原始动画校对

**新增文件与职责：**
- `game/presentation/classic/clock_view.gd`：模型生命周期和确定时间采样。
- `game/ui/war3/scenes/retail_clock.tscn`：TextureRect、SubViewport、相机、环境与固定坐标。
- `game/tests/test_classic_clock.gd`：模型、动画、暂停和重复绑定回归。
- `game/tests/capture_classic_clock.gd`：实际渲染两段原始序列的固定时间点。

**接口：**
- `bind_model(path: String) -> bool`：释放旧模型后加载原始数据；失败明确返回 false。
- `sample_sequence(index: int, seconds: float) -> void`：选择精确序列并定位时间，不改变游戏规则。
- `advance(delta: float) -> void`：仅推进表现；`paused: bool` 为真时不推进。
- 模型默认路径：`res://art/classic/ui/console/human/humanui-timeindicator.json`。

- [x] 写失败测试：加载专用组件，检查上述接口、Stand/Stand Alternate、13 个网格和有效原始纹理依赖。
- [x] 运行 `Godot --headless --path game --script res://tests/test_classic_clock.gd`，确认失败来自组件缺失。
- [x] 实现组件；复用模型加载器，不改写通用英雄骨骼或材质代码。检查原始顶点范围及 UI 配置，确定相机轴向、正交尺寸和中心，并在场景中写清依据。
- [x] 补齐并运行暂停/恢复、零时间、重复绑定和序列边界检查；不允许把错误脚本的零退出码当成功。
- [x] 图形运行截图脚本，覆盖两段序列各 0、15、30 秒；检查透明、盘面朝向、裁剪及动画变化。若现有加载器无法表达关键效果，记录具体缺口并暂停 HUD 替换，不使用替代美术蒙混。
- [x] 运行源码行数检查，独立提交可验证的组件和回归。

## 任务二：HUD 接入、暂停与验收记录

**修改文件与职责：**
- `game/ui/war3/scenes/retail_hud.tscn`：在相同位置实例化已验证组件。
- `game/ui/war3/scripts/retail_hud.gd`：移除对应种族的旧静态时钟纹理赋值，避免覆盖视口纹理。
- `game/ui/war3/scripts/live_training.gd`：同步训练暂停状态，不改权威时钟。
- `game/tests/test_classic_clock_hud.gd`：接入、暂停、旧框重复与规则只读检查。
- `docs/classic-clock.md`、`docs/roadmap.md`：来源、取景、截图及未验收边界。

**接口：** HUD 的 `Clock` 保持原节点路径，提供任务一的 `paused` 与时间采样接口；其他未验证种族保持静态资源路径，不声称它们已完成模型还原。

- [x] 先写失败测试：训练 HUD 应使用时钟视口；暂停不推进；同一状态刷新不重复创建模型，规则摘要不变。
- [x] 实施近卫场景接入与暂停同步，确保不叠加原模型框和旧静态框。
- [x] 运行专项测试并截图完整 1024×768 HUD，检查与头像、菜单和顶部时钟区域的遮挡关系。
- [x] 运行 `python3 tools/check_project.py --godot .tools/Godot.app/Contents/MacOS/Godot`、`python3 tools/classic_art/check_assets.py`、`python3 tools/check_source_limits.py`。
- [x] 中文记录实际验证结果与原版时间映射、混合、种族及 Windows/Linux 的未验收项；分别提交实现与视觉记录，不自动推送。

## 执行建议

建议在当前会话由同一代理逐项执行，两项任务共享模型取景与接口，串行执行更易保持一致；不需要并行子代理。已有工作区是否需要隔离，在执行开始时按仓库状态和 worktree 技能检查决定，不擅自移动用户工作。

## 执行记录

- 2026-10-25：用户已批准计划并选择当前会话串行执行。保留当前工作区，以复用已核验的忽略资源缓存；不迁移用户未提交的设计/计划文件。
- 裁定：原始 UI 骨骼 `sunrise/set` 触发 Godot 名称限制，造成骨索引错位；允许对通用加载器做最小名称规范化，原始数据及 ObjectId 不变。此为已定位错误修复，不新增模型算法。
- 裁定：源模型另缺两张纹理，将 UI 模型加入既有依赖解析入口，补齐并验证原始摘要。
- 证据：独立组件缺失测试先失败，HUD 静态入口测试先失败；实现后两个专项通过。图形检查六个原始序列时间点及完整近卫 HUD；记录透明像素结果。
- 证据：工程统一回归通过；最终重绑皮肤修正重跑专项；资源摘要与源码行数通过。原始时间映射、精确混合、种族一致性及 Windows/Linux 保持未验收。

- 最终只读独立审查：未发现阻止交付的重要问题；未重复运行已完成测试。
