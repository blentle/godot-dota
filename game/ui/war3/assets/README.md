# 资源来源与替换契约

本目录 PNG 全部为本项目编写的程序测试纹理，不是 Warcraft III 导出素材。`DISBTN_test.png` 是独立、预先保存的灰度 PNG；运行时不从 BTN 生成灰度，也没有灰度 shader。当前实现不满足原版贴图或 95% 视觉验收。

`font.tres` 使用打包 Friz Quadrata 西文与 Song Light 中文候选，固定回退链，关闭抗锯齿、子像素、mipmap 及系统回退。来源摘要和语言包验收边界见 `docs/classic-fonts.md`；原版中文字形、字号和基线仍未验收。

| 文件 | 像素尺寸 | 用途 |
| --- | --- | --- |
| BTN_test / AHK_test / DISBTN_test.png | 64×64 | 正常、透明边缘高亮、完整灰度图 |
| health / mana / experience.png | 1024×16 | 固定宽度纹理，通过外层裁剪改变填充 |
| panel.png | 1024×256 | 面板测试底图 |
| tooltip.png | 512×256 | 提示框测试底图 |
| board.png | 512×512 | 表格测试底图 |
| frame.png | 256×256 | 透明内区边框 |
| slot.png | 64×64 | 空槽及条背景 |
| map_test.png | 256×256 | 小地图渲染视口测试底图 |
| gold / lumber / strength / agility / intelligence.png | 32×32 | 资源和属性测试图标 |

正式替换时，每种技能、物品和头像必须有对应的正常图与预导出灰图；技能/物品另提供 AHK 透明高亮边框。不得把所有正式技能继续指向同一测试图。所有 PNG 维持二次幂尺寸，透明素材不做预乘 alpha，无损导入，mipmap 关闭；采样和 Repeat 在场景 CanvasItem 上设置。
