# 源码边界与设计模式

永久约束统一维护在根目录 `AGENTS.md`。所有自有源码单文件不超过 500 行；本轮拆分不只为了行数，而是拆除混合职责。

## 当前模块

| 模块 | 职责 | 不负责 |
|---|---|---|
| `world/battlefield.gd` | 装配组件、转交命令、连接事件 | 地形细节、寻路算法、伤害结算 |
| `world/terrain_builder.gd` | 构建示意地形并登记障碍 | 输入与战斗 |
| `presentation/mesh_factory.gd` | 创建临时网格并缓存材质 | 游戏规则 |
| `presentation/unit_view.gd` | 单位模型、血条、动作与受击反馈 | 修改生命、金币或冷却 |
| `presentation/camera_rig.gd` | 镜头平移、缩放、世界坐标转换 | 玩家位置与路径 |
| `input/battle_input.gd` | 输入到命令的适配 | 决定命中与花费 |
| `ui/classic_hud.gd` | 呈现状态、原生按钮、暂停菜单 | 直接更改权威战斗数据 |
| `ui/minimap_view.gd` | 小地图投影、标记与操作 | 场景生成 |
| `simulation/training_world.gd` | 组合导航与战斗，协调移动/追击 | 渲染与键鼠 API |
| `simulation/grid_navigation.gd` | AStar 网格路径策略 | 生命与技能 |
| `simulation/combat/unit_state.gd` | 单位战斗状态 | 渲染与命令验证 |
| `simulation/combat/command_chain.gd` | 无副作用校验责任链 | 扣费、伤害和奖励 |
| `simulation/combat/combat_system.gd` | 前摇、冷却、技能、伤害、死亡和复活 | 地形、界面和输入 |
| `tests/scenario_smoke.gd` | 场景回归 | 产品业务 |

以上路径均相对于 `game/`。测试从正式场景装配脚本移出，只有显式 `--smoke-test` 才动态加载。

## 战斗指令责任链

调用方组装命令上下文：发起者、目标、距离上限、魔法消耗和当前冷却。链条依次检查：

1. 发起者存活且未眩晕。
2. 目标存活且不是发起者自身。
3. 目标位于允许范围。
4. 发起者魔法足够。
5. 冷却已经结束。

任一步失败立即返回中文原因，后续步骤不再执行。全部通过后，由战斗系统一次性提交魔法消耗、冷却和效果；链条本身无副作用。

普通攻击在命令接受时进入前摇，前摇结束再次检查目标存活与距离，再结算伤害。伤害从存活转为死亡时只结算一次奖励。待命中目标只记录稳定 ID，避免两个单位互相持有引用形成循环。

追击属于世界协调逻辑：先规划路径，到达攻击距离后停止移动，并请求战斗系统攻击。导航、校验链、命中、视觉反馈不混在一个函数里。

## 事件与表现隔离

战斗系统发出攻击、受伤、技能、死亡、复活事件；场景协调器将事件交给单位视图与 HUD。规则测试不需要窗口、模型或字体即可运行。

当前是训练模型，尚无网络服务身份、队伍权限等校验。未来接入网络时应在命令入口前增加协议与控制权责任链，而不是让客户端视图直接调用伤害结算。

## 交付检查

```sh
python3 tools/check_source_limits.py
python3 -m unittest discover -s tests -v
python3 tools/run_client.py --headless -- --smoke-test
python3 tools/run_client.py --headless --script res://tests/test_training.gd
python3 tools/run_client.py --headless --script res://tests/test_combat.gd
```

行数工具包含空行和注释。规则文件要求禁止把自有业务代码放进依赖/生成目录以规避检查。代码审阅仍需判断模块是否单一职责，自动行数检查不能代替设计判断。
