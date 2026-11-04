# 原始树木还原：来源核对

用户要求继续视觉还原；本轮开始替换圆锥占位树前的来源核对。训练树位与规则障碍暂不改变。

运行 `node tools/classic_art/read_tree_sources.cjs`：先验证固定地图 SHA-256，再只读解析 war3map.doo 与 war3map.w3b，保留两文件摘要、全部放置类型计数和原始对象覆盖。输出 `references/classic-tree-sources.json`，不执行 JASS。

当前地图放置 ATtr 2061 项，变体 0～4；NTtw 1551 项，变体 0～9。ATtr 对象覆盖包含三个颜色通道均为 190。自定义对象中还有与技能相关的树木配置，不能直接当作地形树。

地图没有内置 Units/DestructableData.slk；已定位固定经典镜像中的 lowercase/units/destructabledata.slk，Git blob 摘要 de251ef6cf55ea9be741f97ee2aa53d833e5a6b3。下一步须校验并合并该基础对象表，确定两树种模型、替换纹理编号和变体命名，再接入表现。不得将全部树套用单一洛丹伦资源。

提取工具实际运行成功，204 个自有源码文件行数检查通过。本轮未修改游戏画面；树木模型、纹理和实机对照仍未完成。
