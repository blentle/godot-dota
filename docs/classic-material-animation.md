# 经典模型表面与头像时间轨

本轮只补表现，训练生命、伤害、魔法、冷却与英雄规则保持原有开发配置。

## 补齐的表现

- `material_animation.gd` 按原始材质的 `TVertexAnimId` 采样纹理平移；时间来自模型动作或全局序列。切换 Stand、Walk、Attack 不重置全局纹理时钟。当前已导入资源的 21 组 UV 时间轨均为平移。
- Geoset 的颜色、透明度与层 Alpha 相乘；同一源材质被多个 Geoset 引用时，各自拥有独立材质实例和完整 next_pass 链，避免最后一次更新覆盖所有部件。
- 源格式的静态 Geoset 颜色为 RGB，颜色动画时间轨为 BGR；必须分别解释。未启用颜色位时忽略颜色字段，不能把未定义黑色值乘到模型上。
- `portrait_camera.gd` 读取原始相机位置、目标位移、滚转和裁剪范围，与头像骨骼共用动作时钟。暂停时同时冻结；重复更新不累加滚转；换到没有相机的资源时清空旧轨道。
- 经典材质 Transparent 模式的 Alpha Test 阈值改为 0.75；HUD 的独立 BTN/AHK/DISBTN 贴图及输入逻辑不受这项模型材质设置影响。

相机轨道接入不等于给所有头像添加运镜。已导入模型的首个 Portrait 片段中，许多相机轨道是常量，仍应保持原本静态取景，不人为加入摇晃。

## 来源解释

模型数据仍来自既有 `provenance.json` 和地图摘要，没有新增或替换英雄美术。本轮对照已锁定的 `mdx-m3-viewer 5.12.0` 中 Geoset、UV 和相机字段处理，核对二进制静态颜色与动画颜色的通道差异；自有实现保留在正常源码目录，不复制第三方大文件为业务模块。

## 验证

- `test_classic_surface_animation.gd`：真实电魂模型半秒滚动四分之一纹理、切动作后全局时钟连续、周期回绕；共材质部件隔离；静态 RGB 与动画 BGR；隐藏和恢复不留旧颜色。
- `test_classic_portrait_camera.gd`：原始吉安娜头像模型配受控轨道，验证世界单位缩放、目标位移、滚转、重复更新、缺相机清理以及暂停/恢复。
- 214 个去重后的英雄本体及头像继续通过构建与动作推进冒烟；工程统一规则和场景回归通过。
- macOS Apple Silicon 使用固定表现时间点 0 秒、0.45 秒截取水人及电魂画面；原始颜色、水体贴图、动态头像均能显示。静态截图不代替动画逐帧对照。

可重复截图命令：

```sh
.tools/Godot.app/Contents/MacOS/Godot --path game --script res://tests/capture_classic_motion.gd -- --classic-hero=O00P --capture-prefix=/tmp/morphling
```

工具冻结训练规则，只推进表现时间轨；输出两个 PNG。`E002` 可切换为电魂，`Uktl` 为谜团。

## 尚未完成

粒子、飘带、部分节点标志、UV 旋转及 modulate2x 的精确混合仍未完成；本轮没有将这些缺口计入完整还原。地形、树和建筑仍为占位美术。整体 UI 字体与坐标、逐英雄实机对照继续待验收；Windows、Linux 尚未实测。
