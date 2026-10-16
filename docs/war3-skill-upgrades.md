# 经典 HUD 训练技能升级

## 运行与操作

使用 Godot 4.7.2：

```sh
godot --path game -- --war3-training
```

英雄面板中间新增技能点和三个“+”按钮，分别对应 Q 震击、W 冲击、E 召唤。
按钮下方显示按键和当前等级，例如 `W2/4`。有可用点数并满足规则门槛时点击升级；禁用时悬停查看原因。
升级结果显示在战场底部通知中。Q/W/E 键继续用于施法，升级由鼠标点击，不新增容易误按的升级快捷键。

这是开发成长规则：三个技能初始均为 1 级，最大 4 级，每次英雄升级获得 1 点，技能的后续升级要求英雄达到 2/4/6 级。
这些规则和数值未校对 DotA 6.83d 原版英雄，界面纹理和字体也仍是占位资源。

## 场景与职责

```text
LiveTraining（1024×768）
└── Interface（CanvasLayer）
    ├── HUD
    ├── SkillUpgrades（Control，skill_upgrades.tscn）
    │   ├── Points（Label）
    │   ├── Upgrade0…2（upgrade_action.tscn）
    │   │   └── BTN / AHK / DISBTN、CooldownText、Text（+）
    │   ├── Rank0…2（Label）
    │   └── Feedback（Label）
    ├── ShopToggle
    └── Shop
```

| 文件 | 职责 |
| --- | --- |
| `game/ui/war3/scenes/skill_upgrades.tscn` | 固定技能点、三个按钮、等级和反馈布局 |
| `game/ui/war3/scenes/upgrade_action.tscn` | 36×36 的加号按钮，复用既有三层贴图与输入组件 |
| `game/ui/war3/scripts/skill_upgrades.gd` | 只读状态、拒绝原因、升级命令和结果信号 |
| `game/ui/war3/scripts/training_snapshot.gd` | 将技能等级映射为真实成长效果说明 |
| `game/ui/war3/scripts/live_training.gd` | 装配组件、隔离商店状态并显示结果 |

按钮调用 `world.submit_upgrade(kind)`；可用性读取 `world.upgrade_reason(kind)`。
表现层不扣技能点，不修改技能等级、魔法、冷却或已有守卫属性。
选择状态、暂停与商店遮挡在组件入口检查，死亡、等级、技能点、满级和终局仍由规则入口裁定。
每次刷新都读取权威等级；提示框内容改变时按既有延迟重新展示，未变化时不重置悬浮计时。

## 固定坐标

所有坐标基于 1024×768，锚点为零。现有技能、物品、血蓝条、小地图位置保持原坐标。

| 元素 | 绝对坐标和尺寸 |
| --- | --- |
| 升级组件根 | `(620,574,128,112)` |
| 技能点 | `(620,574,128,20)` |
| 升级按钮 i，0≤i<3 | `(620+44i,598,36,36)` |
| 按钮加号文字 | 与按钮相同的矩形，居中 |
| 等级标签 i | `(620+44i,638,36,20)` |
| 组件反馈 | `(620,660,128,20)` |
| 完整结果通知 | 既有 `(12,520,1000,24)` |

保持最近邻采样、关闭字体抗锯齿，使用独立 BTN/AHK/DISBTN PNG，没有新增 shader、Theme、圆角、阴影或动画。

## 验证与边界

```sh
godot --headless --path game --script res://tests/test_war3_upgrades.gd
godot --headless --path game --script res://tests/test_skill_training.gd
```

场景回归通过真实鼠标点击验证：无点数拒绝、经验发点、升级扣点、重复点击、等级限制、满级、选择/暂停/死亡/商店限制、按下期间禁用再恢复、伤害提示与实际命中一致。
验证升级不刷新已有冷却、不回魔、不改变金币；召唤技能提示只描述新守卫的成长属性。
既有规则回归覆盖服务器升级命令幂等、快照恢复和已有守卫不随升级变化。

本轮在 macOS Godot 4.7.2 通过窗口截图检查，按钮和等级标签没有遮挡。商店、真实训练回归通过。
Windows/Linux 尚未实测；真实训练入口的选人、重开、模式切换和结算仍需接入经典界面，默认旧入口保留。
