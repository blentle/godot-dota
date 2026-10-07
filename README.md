# DotA 6.83d · Godot 重制工程

当前阶段：离线训练原型，已加入单对手战斗与三路兵线演练，并在 macOS 运行；尚未完成原版 UI、正式英雄全集、完整对局或平台服务。

目标：先完成经典 Warcraft III DotA 6.83d 客户端与完整规则，再完成注册登录、房间、10 人匹配、本地启动和服务器部署。

- 引擎锁定：**Godot 4.7.2 Standard / GDScript**。
- 首发目标：Windows x86_64、macOS（Apple Silicon / Intel）、Linux x86_64 均提供游戏客户端和平台启动器；对战服务器部署于 Linux x86_64。
- 游戏采用 3D 地形与单位、固定俯视相机和 2D HUD。
- 本仓库不包含 Warcraft III / DotA 原始地图、美术、音频或已校对的英雄数据。

## 文档

- [系统架构](docs/architecture.md)
- [实施顺序与验收](docs/roadmap.md)
- [版本、英雄、素材与 UI 验收](docs/content-and-fidelity.md)
- [平台与游戏协议草案](docs/protocol.md)
- [素材与参考来源](docs/sources.md)
- [三平台交付矩阵](docs/platforms.md)
- [M1 操作说明与限制](docs/m1-progress.md)
- [训练战斗操作与参数](docs/m2-combat.md)
- [三路兵线、建筑与胜负演练](docs/m2-lanes.md)
- [经济、商店与装备](docs/m2-economy.md)
- [源码职责与责任链](docs/code-structure.md)
- [永久开发约束](AGENTS.md)

## 当前骨架运行

安装指定版本后，在仓库根目录执行：

```sh
python3 tools/run_client.py
python3 tools/check_source_limits.py
godot --path game
godot --headless --path game -- --validate-content
godot --headless --path game -- --server --validate-content
godot --headless --path game -- --smoke-test
godot --headless --path game --script res://tests/test_training.gd
godot --headless --path game --script res://tests/test_combat.gd
godot --headless --path game --script res://tests/test_lanes.gd
godot --headless --path game --script res://tests/test_projectiles.gd
godot --headless --path game --script res://tests/test_economy.gd
godot --headless --path game -- --lanes --smoke-test
python3 tools/validate_content.py
python3 -m unittest discover -s tests -v
```

默认入口打开离线训练场景，校验参数只检查版本后退出。`--server` 单独使用明确报错，尚无可用对战服务。操作：右键移动/攻击对手、A 追击、Q 训练震击、方向键平移镜头、滚轮缩放、F1 返回单位、Esc 菜单。

Esc 菜单可切换“三路兵线演练”，体验近战/远程刷兵、追踪弹道、防御塔攻击、建筑保护和基地摧毁胜负；也可用 `python3 tools/run_client.py -- --lanes` 直接进入。按 B 打开基地商店，购买四种开发装备；点击背包物品后可出售。

Python 校验器不依赖第三方库。发布检查使用 `python3 tools/validate_content.py --release`；当前会有意失败，因为参考地图、英雄数据与验收尚未完成。

## 目录边界

```text
game/                    Godot 客户端与无界面服务器共用工程
  bootstrap/             入口与启动参数
  world/                 场景装配与地形构建
  presentation/          相机、单位视图与几何工厂
  input/                 输入到命令的适配
  simulation/            导航、战斗与权威训练状态
  ui/                    HUD 与独立小地图
  tests/                 引擎规则和场景回归
  content/6.83d/          版本清单与后续经校对的数据
docs/                    架构、协议和验收标准
tools/                   内容校验与后续构建工具
tests/                   工程工具回归测试
```

平台将在 M5 增加 `launcher/`、`services/platform/` 和 `deploy/`，避免在游戏边界未稳定时铺开多个空工程。

版本来源：[Godot 4.7.2 官方归档](https://godotengine.org/download/archive/4.7.2-stable/)。
