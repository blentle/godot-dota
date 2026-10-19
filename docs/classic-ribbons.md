# 原始飘带基础表现

本轮继续优先英雄外观，接入原模型 `RibbonEmitters`。当前导入资源含 22 个带飘带的本体/头像模型、39 个发射器；数量不代表正式英雄完成度。

## 行为和职责

- `ribbon_system.gd` 管理固定 60 Hz 子步、原始发射率、可见性、寿命、截面池及断带。
- `effect_tracks.gd` 按指定子步时间读取原始动作或全局轨道。
- `effect_pose.gd` 按源骨骼层级计算子步世界变换，不修改可见 Skeleton。相同时间点结果与现有骨骼结果比较。
- `ribbon_batch.gd` 将同一条轨迹的相邻截面连成三角形，使用原始材质、层 Alpha、颜色及纹理图集。

原始 HeightAbove/HeightBelow 沿节点局部 Y 轴展开，再经过完整骨骼和模型变换。已经发射的截面保存在世界空间，不跟随单位当前坐标整体移动。纹理按 TextureSlot、Rows、Columns 和截面寿命位置展开，不用一张通用光带替换原图。

可见性或 Alpha 关闭后停止新发射，已有截面继续老化。可见性恢复时开启新链，不能连接到上一段残留截面。同位置的重复截面不提交退化三角形，没有可连接截面时不创建空表面。

每个发射器最多使用 128 个可复用截面，单次追帧最多两秒；超限发射和丢弃时间有独立计数。暂停和零时间推进不会发射或老化，重新绑定不能累加旧池。飘带材质单独实例化，不能混入 Geoset 材质更新列表。

## 为什么要子步骨骼采样

只在推进结束时读取骨骼，会让一次 0.45 秒推进中的所有截面重叠在同一位置，飘带实际上不可见。本轮按每个子步读取位置、旋转和缩放轨道，并递归合成父骨骼变换，保留挥砍路径。全局动作时钟沿用原模型，不人为画圆弧替代动画轨迹。

三类发射器现已接入该骨骼采样器，普通粒子的回归见 [粒子说明](classic-particles.md)。单位根节点的帧内世界位移、显式瞬移清理及部分节点标志仍需补齐，不能据此宣称全部轨迹精确还原。

## 验证

- `test_classic_ribbons.gd`：数量与池守恒、局部高度轴、世界空间截面、图集取格、颜色/Alpha、材质隔离、暂停、隐藏/恢复断带、回收、容量与跳时上限、重复绑定。
- `test_classic_effect_pose.gd`：山丘和普罗德摩尔的子步矩阵与可见 Skeleton 比较；取样不改写可见姿态；一次推进 0.45 秒必须生成真实挥砍轨迹。
- 全模型冒烟现在额外检查运行时发射器数量与源配置相同，避免只看模型加载返回值而漏掉部分绑定失败。
- macOS Apple Silicon 的船长 Attack 近景检查：初始零段，0.45 秒时实际绘制三段飘带。截图不代替 Warcraft III 1.26 的逐帧比对。

复现：

```sh
.tools/Godot.app/Contents/MacOS/Godot --path game --script res://tests/capture_classic_motion.gd -- --classic-hero=H06S --classic-action=Attack --classic-zoom=12 --capture-prefix=/tmp/admiral
```

`--classic-action` 只切换外观动作，`--classic-zoom` 只调整截图相机；训练规则不随之改变。

## 未完成项

15 个旧式 ParticleEmitter 已接入基础模型抛射，详见 [旧式模型粒子](classic-model-particles.md)。飘带重力、UV 方向、精确混合和部分节点标志仍需逐模型核对。地形、树、建筑依然是占位美术，整体 UI 字体、部分坐标及逐英雄实机验收未完成。Windows、Linux 尚未实测。
