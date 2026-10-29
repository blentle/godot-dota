# 经典 HUD 的固定字体链

## 本轮变更

原先 `font.tres` 依次查询系统宋体，不同平台可能得到不同字形、字宽和缺字回退。本轮保留 1024×768 画布、现有字号、颜色和所有坐标，替换为项目内固定字体链：西文 `Friz Quadrata TT`，中文候选 `Song Light`。兼容控制台与选人/结算会话共用该资源，避免隐藏兼容面板继续扫描系统字体。

字体来自固定经典资源副本 `bce1f9d87ab7d71e208624dbbdce208db5690d4f` 的 `extract/Fonts/`。已有原始 `ui/war3skins.txt` 的 MasterFont、MessageFont、ChatFont、EscMenuTextFont、InfoPanelTextFont、TextTagFont 均指定 `Fonts\\FRIZQT__.TTF`。这可支持西文字体选择，但不能证明本副本与 Warcraft III 1.26 简体语言包完全一致。

六个候选均下载到忽略缓存，逐一验证长度及 Git blob 摘要；实际打包两个：

| 文件 | 引擎读取的名称 | 角色与边界 |
| --- | --- | --- |
| `frizqt__.ttf` | Friz Quadrata TT | 原始配置指定西文，252 个支持字符 |
| `dfst-m3u.ttf` | Song Light | 简体中文候选，7540 个支持字符；语言包对应仍待实机核对 |

`DFKGothic-Md` 等候选并不覆盖测试中的简体“击”，不能仅凭文件名猜测语言。字体名称、覆盖和运行设置由 Godot 实际读取验证。本轮没有把候选字体称作已经验收的 1.26 简体原版字体。

## 导入设置

两份 `.ttf.import` 均显式设置：`antialiasing=0`、`subpixel_positioning=0`、`generate_mipmaps=false`、`multichannel_signed_distance_field=false`、`allow_system_fallback=false`、`oversampling=1.0`。字体资源使用 FontVariation 包装打包 FontFile，并固定唯一中文回退；不使用 Theme 改写原版控件布局。

字体不适用 PNG 的二次幂尺寸约束。字符缺失应通过测试暴露，不能静默依赖宿主系统补字。字体仍归原权利人，来源固定不等于取得发行授权，见美术 NOTICE。

## 工具与验证

- `fetch_fonts.cjs`：读取已固定 Git 树，下载字体并核验 blob；直接传递 curl 参数，不拼接 shell。
- `prepare_fonts.py`：核验后只打包选中的两份文件，生成 `fonts/sources.json`。
- `test_classic_fonts.gd`：验证实际字体类型、名称、常用中英文字形、固定回退、无平滑设置及固定布局内的文字测量。
- `check_war3_hud_assets.py`：同时检查字体导入设置及禁止 SystemFont。

首轮实机/整工程检查发现隐藏兼容界面仍查询系统字体并产生 FreeType 错误，随后统一为打包字体；第二轮 macOS Apple Silicon 实机截图已无字体加载错误。当前截图中的文字可读，未调整英雄名称、标签和资源数字字号。

修正后的整工程回归、1570 项来源摘要及 187 个自有源码文件行数检查通过。界面检测器不支持完整判断 Godot 字体资源，检测无发现不能替代引擎运行测试和截图检查。

原版字号、字距、基线和中文语言包尚未逐项对照，不能据此声明 95% 视觉验收。Windows、Linux 尚未实测；整体地形仍为占位美术。
