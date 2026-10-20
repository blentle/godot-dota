extends SceneTree
## 固定原始字体链：禁止系统回退，检查像素渲染设置及实际 HUD 字形覆盖。

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var font: Font = load("res://ui/war3/assets/font.tres")
	check(font is FontVariation and font.base_font is FontFile, "经典 HUD 必须引用打包字体")
	check(font.base_font.get_font_name() == "Friz Quadrata TT", "西文必须来自原始配置指定的 Friz Quadrata")
	check(font.fallbacks.size() == 1, "中文回退链应固定，避免系统依赖")
	for source in [font.base_font, font.fallbacks[0]]:
		check(source.antialiasing == TextServer.FONT_ANTIALIASING_NONE, "字体必须关闭抗锯齿")
		check(source.subpixel_positioning == TextServer.SUBPIXEL_POSITIONING_DISABLED, "字体必须关闭子像素定位")
		check(not source.allow_system_fallback, "不得静默回退到系统字体")
		check(not source.generate_mipmaps and not source.multichannel_signed_distance_field, "字体不得开启 mipmap 或 MSDF")
	for character in "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz力量敏捷智力物品栏金币复活生命魔法冷却技能攻击防御移动停止保持位置菜单聊天选项传送训练商店经验英雄":
		check(font.has_char(character.unicode_at(0)), "打包字体缺少 HUD 字形："+character)
	var sample := "力量 24  MP 240/240"
	var width: float = font.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	check(width > 0 and width < 220, "字体测量应适合当前固定布局")
	print("经典打包字体回归，失败数：", failures)
	quit(1 if failures else 0)
