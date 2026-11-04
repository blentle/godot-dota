# 原始防御塔外观接入

## 范围与来源

用户于 2026-11-04 选择直接推进原始防御塔替换。经典入口六座训练塔接入原始模型，基地、树木、地面和训练地图位置仍为开发占位；本次不恢复原版地图布局、攻击数值、弹道、等级或规则。

`python3 -m tools.classic_art.build_tower_catalog` 从已记录摘要的地图配置生成 `game/art/classic/tower-catalog.json`。读取前校验 unitui.slk、nightelfunitfunc.txt、undeadunitfunc.txt 的 SHA-256；保留八项配置的单位代码、模型缩放、颜色和动画标签。

| 阵营 | 地图单位代码（一级至四级） | 模型 | 形态标签 |
|---|---|---|---|
| 近卫 | e00R、e011、e00S、e019 | AncientProtector | 配置未指定附加标签 |
| 天灾 | u00M、u00D、u00N、u00T | Ziggurat | 前三级 upgrade,first；四级 upgrade,second |

原始 MDX 与贴图沿用固定经典资源镜像的下载、摘要校验和转换流程。新增 Ziggurat 本体、bluesqglow 及 teamcolor06；部分依赖此前已用于英雄。来源清单和转换出处随资源保留。地图候选尚未独立核验为官方发行副本，模型来自固定经典镜像，不视为原版实机验收已经完成。

## 运行与职责

无参数或 `--war3-training` 的经典入口替换六座塔；`--legacy-client` 路径保留旧训练几何。terrain_builder 只负责装配及原有障碍登记；tower_view 读取外观目录并消费状态及攻击事件；army_view 负责将建筑规则状态、攻击事件送到对应表现。复用既有模型加载器，不建立第二套动画运行时。

训练塔没有正式等级，本次统一使用一级外观。近卫读取默认 Stand；天灾读取 Stand Upgrade First，不显示普通未升级通灵塔。动作选择器补充 first/second 标签区分，四级配置可正确选择 Stand Upgrade Second，但未在训练中新增升级入口。

暂停以零时间步长保持模型时钟；攻击事件播放原始 Attack；死亡转原始 Death，不再压扁模型。资源加载失败时退回现有训练占位几何。原有规则障碍、生命、攻击数值、基地和地图坐标不由表现层改写。队色使用经典阵营槽位红色/绿色；所有模式的队色映射与原版像素对照尚未验收。

## 验证记录

`test_classic_tower.gd` 在组件缺失时失败；实现后检查两阵营源模型、默认形态、暂停、攻击、死亡、二级升级形态选择，以及经典/旧表现的六塔双基地数量和障碍登记一致性。

图形截图工具：

```sh
.tools/Godot.app/Contents/MacOS/Godot --path game --script res://tests/capture_classic_towers.gd
```

输出 `/tmp/classic-tower-0.png`、`/tmp/classic-tower-1.png`，冻结规则后分别取近卫与天灾塔的固定视角。macOS Apple Silicon 实机可见原始大树及升级通灵塔，截图日志无 ERROR。树、道路和基地仍是占位，尺寸、朝向、队色与原版逐像素比对未完成；Windows、Linux 未验收。

整工程统一规则/场景回归通过，追加升级形态专项通过；202 个自有源码文件均未超限。资源静态检查通过：112 位英雄、1356 张二次幂 PNG、1577 项来源摘要。独立只读审查未发现阻塞缺陷；当前攻击事件路由经过代码审查，专项测试直接调用塔视图，尚缺真实事件链及另一座塔不受影响的自动化断言。截图归档于 `references/previews/classic-towers/`。

## 真实事件链回归补充

新增 `test_classic_tower_events.gd`，实例化实际经典训练场，登记六座塔后通过 combat_event 信号发送攻击事件，覆盖 battlefield → army_view → building_units → tower_view。断言攻击者动作代次增加、目标塔动作不变、目标生命不变，以及零时间同步不推进动画。专项在 macOS Godot 4.7.2 通过，日志无 ERROR；203 个自有源码文件行数检查通过。该测试补齐上次审查中的事件路由缺口，不代表攻击时序或原版视觉已验收。
