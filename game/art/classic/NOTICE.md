# 第三方经典游戏美术说明

本目录的经典贴图、模型中间数据、图标及其组合图来自 Warcraft III 和 DotA 地图资源，版权归原作者及相关权利人。它们不是本项目原创美术，不因资源镜像仓库的代码许可证而改为本项目所有，也不在此授予商业发行或再授权许可。

- 经典资源镜像：https://github.com/WarRaft/War3.mpq ，固定提交见 `references/classic-art-sources.json`。
- DotA 6.83d 地图下载候选：https://gaming-tools.com/warcraft-3/?ddownload=1418 ，文件摘要及验证边界见 `references/dota-683d-archive.json`。
- `provenance.json` 逐项记录原始路径、摘要和转换输出；地图内资源另记地图 SHA-256。镜像内容尚未与已安装的 Warcraft III 1.26 官方资源逐项比对。
- `console-*.png`、面板和菜单状态图由原始图集按固定坐标提取、拼接及最近邻缩放；不是 AI 生成美术。
- 模型 JSON 保留原 MDX v800 的骨骼、网格、动画和材质信息，供项目运行时读取。转换不会执行地图 JASS 脚本。
- `hero-catalog.json` 来自地图酒馆及单位配置，共 112 项。目录完整不等于 112 位英雄玩法或外观验收完成。

转换工具依赖的 war3-model、mdx-m3-viewer、pngjs 保留各自许可证；安装位置为 `.tools/classic-art/node_modules`，不将第三方实现复制为自有业务代码。

字体 `fonts/frizqt__.ttf` 与 `fonts/dfst-m3u.ttf` 同样来自上述固定资源副本，保留原始二进制及内嵌版权信息；来源记录在 `fonts/sources.json`，不适用镜像代码许可证。中文语言包对应关系尚未验收。
