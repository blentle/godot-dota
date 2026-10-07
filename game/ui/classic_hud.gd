extends Control
## 训练场景界面：呈现规则状态和命令入口，数值与美术均为开发版本。

var battle: Node3D
var font := SystemFont.new()
var notice := "右键移动 · 方向键移动镜头 · F1 返回单位"
var menu: Panel
const Minimap = preload("res://ui/minimap_view.gd")
var minimap_view: Control
var skill_button: Button
var attack_button: Button
var gold := Color("c6ab70")
var parchment := Color("e1d7bb")
var muted := Color("aaa58e")
var commands: Array[Button] = []
var resume_button: Button
var previous_focus: Control
var inventory_buttons: Array[Button] = []
var shop: Panel
const Catalog = preload("res://simulation/item_catalog.gd")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font.font_names = PackedStringArray(["PingFang SC", "Microsoft YaHei", "Noto Sans CJK SC", "WenQuanYi Zen Hei"])
	var top := Control.new()
	top.position = Vector2.ZERO
	top.size = Vector2(1280, 38)
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(top)
	var bottom := Control.new()
	bottom.position = Vector2(0, 526)
	bottom.size = Vector2(1280, 194)
	bottom.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bottom)
	minimap_view = Minimap.new()
	minimap_view.battle = battle
	add_child(minimap_view)
	_button("菜单  F10", Rect2(16, 7, 102, 25), "menu", "打开离线训练菜单")
	_button("选择单位  F1", Rect2(17, 60, 116, 38), "center", "选择训练单位并将镜头移回单位")
	_button("移动\nM", Rect2(992, 554, 62, 44), "move", "点击地面指定移动目标；也可以右键移动")
	_button("停止\nS", Rect2(1060, 554, 62, 44), "stop", "取消当前移动指令")
	_button("保持\nH", Rect2(1128, 554, 62, 44), "hold", "清空移动路径并保持当前位置")
	_button("镜头\nF1", Rect2(1196, 554, 62, 44), "center", "镜头返回训练单位")
	attack_button = _button("攻击\nA", Rect2(992, 604, 62, 42), "attack", "追击当前目标；右键敌方单位或建筑可指定目标")
	skill_button = _button("震击\nQ", Rect2(1060, 604, 62, 42), "strike", "训练技能：范围 5，伤害 80，眩晕 1.5 秒，消耗 60 魔法，冷却 6 秒。非原版英雄技能。")
	for i in range(6):
		var index := i + 2
		var button := _button("—", Rect2(992 + (index % 4) * 68, 604 + (index / 4) * 48, 62, 42), "", "此技能槽尚未实现")
		button.disabled = true
	for i in range(6):
		var slot := _button("", Rect2(792 + (i % 3) * 55, 555 + (i / 3) * 57, 49, 49), "", "点击查看或出售物品")
		slot.pressed.connect(func(): shop.open(i))
		inventory_buttons.append(slot)
	_button("商店  B", Rect2(792, 674, 159, 30), "shop", "在基地附近购买和出售装备")
	shop = preload("res://ui/shop_panel.gd").new()
	shop.hud = self
	add_child(shop)
	menu = Panel.new()
	menu.position = Vector2(443, 165)
	menu.size = Vector2(394, 410)
	menu.add_theme_stylebox_override("panel", _style(Color("202620"), gold))
	add_child(menu)
	var heading := Label.new()
	heading.text = "离线训练已暂停"
	heading.position = Vector2(48, 28)
	heading.add_theme_font_override("font", font)
	heading.add_theme_font_size_override("font_size", 23)
	heading.add_theme_color_override("font_color", parchment)
	menu.add_child(heading)
	resume_button = _menu_button("继续训练  Esc", 88, "menu")
	var edge := _menu_button("边缘滚屏：关闭", 148, "edge")
	edge.pressed.connect(func(): edge.text = "边缘滚屏：开启" if battle.edge_scroll else "边缘滚屏：关闭")
	_menu_button("三路兵线演练 / 重新开始", 208, "lanes")
	_menu_button("单对手训练 / 重新开始", 264, "training")
	_menu_button("退出客户端", 320, "quit")
	menu.visible = false

func sync_state() -> void:
	for button in commands:
		button.disabled = not battle.selected or battle.paused or not battle.simulation.combat.player.alive() or battle.simulation.finished()

	var combat: RefCounted = battle.simulation.combat
	var target: RefCounted = battle.simulation.current_target()
	var unavailable: bool = target == null or not target.alive() or target.invulnerable
	skill_button.disabled = skill_button.disabled or combat.player.mana < 60 or combat.player.skill_cooldown > 0 or unavailable or battle.simulation.finished()
	attack_button.disabled = attack_button.disabled or unavailable or battle.simulation.finished()
	skill_button.text = "震击\n%.1f" % combat.player.skill_cooldown if combat.player.skill_cooldown > 0 else "震击\nQ"
	for i in range(6):
		var id: String = battle.simulation.economy.slots[i]
		inventory_buttons[i].text = "—" if id.is_empty() else Catalog.ITEMS[id].short
		inventory_buttons[i].tooltip_text = "空背包格" if id.is_empty() else Catalog.ITEMS[id].description
		inventory_buttons[i].disabled = battle.paused
	shop.sync_state()
	minimap_view.queue_redraw()

func set_paused(value: bool) -> void:
	if value:
		shop.close()
		previous_focus = get_viewport().gui_get_focus_owner()
		menu.visible = true
		resume_button.grab_focus()
	else:
		resume_button.release_focus()
		menu.visible = false
		if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
			previous_focus.grab_focus()
	sync_state()

func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(1)
	result.content_margin_left = 6
	result.content_margin_right = 6
	return result

func _button(text: String, rect: Rect2, action: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.tooltip_text = tooltip
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", parchment)
	button.add_theme_color_override("font_disabled_color", Color("777966"))
	button.add_theme_stylebox_override("normal", _style(Color("29312b"), Color("776947")))
	button.add_theme_stylebox_override("hover", _style(Color("424938"), gold))
	button.add_theme_stylebox_override("pressed", _style(Color("171d18"), gold))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), Color("dfcf99")))
	button.add_theme_stylebox_override("disabled", _style(Color("1b211d"), Color("464b3e")))
	if not action.is_empty():
		button.pressed.connect(func(): battle.command(action))
	if action in ["move", "stop", "hold", "attack", "strike"]:
		commands.append(button)
	add_child(button)
	return button

func _menu_button(text: String, y: float, action: String) -> Button:
	var button := _button(text, Rect2(30, y, 334, 44), action, text)
	remove_child(button)
	menu.add_child(button)
	return button

func _text(at: Vector2, value: String, size: int = 15, color: Color = Color("e1d7bb")) -> void:
	draw_string(font, at + Vector2(1, 1), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("111712"))
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _frame(rect: Rect2) -> void:
	draw_rect(rect, Color("111713"))
	draw_rect(rect, Color("7f765a"), false, 2)
	draw_rect(rect.grow(-4), Color("3b4538"), false, 1)

func _draw() -> void:
	if not is_instance_valid(battle): return
	draw_rect(Rect2(0, 0, 1280, 38), Color("1b221d"))
	draw_line(Vector2(0, 37), Vector2(1280, 37), gold.darkened(0.3), 2)
	_text(Vector2(142, 25), "DotA 6.83d  /  离线训练原型", 16, gold)
	var seconds: int = int(battle.simulation.elapsed)
	_text(Vector2(593, 25), "%02d : %02d" % [seconds / 60, seconds % 60], 17)
	var combat: RefCounted = battle.simulation.combat
	_text(Vector2(910, 25), "训练金币  %d" % combat.gold, 14, gold)
	_text(Vector2(1130, 25), "近卫军团", 15, Color("98b98a"))
	draw_rect(Rect2(16, 108, 184, 70), Color("20281f"))
	var target: RefCounted = battle.simulation.current_target()
	var enemy_status := "没有可攻击目标"
	_text(Vector2(26, 130), {"creep": "敌方小兵", "tower": "敌方防御塔", "base": "敌方基地", "hero": "训练对手"}.get(target.kind, "当前目标") if target != null else "当前目标", 15, gold)
	if target != null:
		enemy_status = "生命 %.0f / %.0f" % [target.hp, target.max_hp]
		if not target.alive(): enemy_status = "复活倒计时 %.1f 秒" % target.respawn_remaining
		elif target.invulnerable: enemy_status = "需先摧毁该方三座塔"
		elif target.stunned > 0: enemy_status = "眩晕 %.1f 秒" % target.stunned
	var match_state: RefCounted = battle.simulation.match_state
	if match_state != null:
		var status := "第 %d 波 · %.0f 秒后刷兵" % [match_state.wave, match_state.next_wave]
		if battle.simulation.finished(): status = ("近卫胜利" if match_state.winner == 0 else "天灾胜利") + " · 菜单可重开"
		_text(Vector2(215, 75), status, 16, gold)
	_text(Vector2(26, 155), enemy_status, 13)

	# 连续石质面板用砖缝和铜色分隔线组织信息。
	draw_rect(Rect2(0, 522, 1280, 198), Color("30392f"))
	for row in range(5):
		for col in range(17):
			var offset := 35 if row % 2 else 0
			var rect := Rect2(col * 82 - offset, 526 + row * 41, 80, 39)
			var tint := 0.015 * ((col * 13 + row * 7) % 5)
			draw_rect(rect, Color("30392f").lightened(tint))
			draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color("505846"), 1)
	draw_line(Vector2(0, 523), Vector2(1280, 523), Color("9b8d61"), 3)
	draw_line(Vector2(0, 528), Vector2(1280, 528), Color("151e17"), 3)
	for x in [7, 190, 329, 571, 776, 974, 1273]:
		draw_line(Vector2(x, 528), Vector2(x, 713), Color("968457"), 2)
		for y in [532, 709]:
			draw_circle(Vector2(x, y), 3, gold)
	_frame(Rect2(202, 541, 115, 127))
	_text(Vector2(218, 565), "训练单位", 17, gold)
	# 盾形符号代表待替换的临时头像。
	var crest := PackedVector2Array([Vector2(236, 580), Vector2(283, 580), Vector2(280, 620), Vector2(259, 639), Vector2(238, 620)])
	draw_colored_polygon(crest, Color("315268"))
	draw_polyline(crest, Color("b1a572"), 2)
	draw_line(Vector2(259, 588), Vector2(259, 627), Color("d1c9ad"), 3)
	draw_line(Vector2(248, 604), Vector2(270, 604), Color("d1c9ad"), 3)
	_text(Vector2(218, 655), "临时外观", 12, muted)
	_bar(Rect2(204, 676, 111, 12), Color("559346"), "%.0f / %.0f" % [combat.player.hp, combat.player.max_hp], combat.player.hp / combat.player.max_hp)
	_bar(Rect2(204, 694, 111, 12), Color("426d9d"), "%.0f / %.0f" % [combat.player.mana, combat.player.max_mana], combat.player.mana / combat.player.max_mana)
	_text(Vector2(346, 552), "近卫训练卫兵" if battle.selected else "未选择单位", 19, gold)
	_text(Vector2(346, 577), "战斗开发数值 · 非正式英雄", 12, muted)
	_text(Vector2(346, 608), "状态    " + battle.simulation.order if battle.selected else "点击单位或按 F1 选择", 14)
	_text(Vector2(346, 633), "移动速度    %.1f 世界单位 / 秒" % combat.player.move_speed, 13)
	_text(Vector2(346, 658), "攻击 %.0f  /  间隔 1 秒  /  距离 2.4" % combat.player.damage, 12, muted)
	_text(Vector2(346, 696), "击杀 %d / 阵亡 %d / 补刀 %d" % [combat.kills, combat.deaths, combat.last_hits], 12, muted)
	_text(Vector2(588, 552), "指令与视野", 17, gold)
	_text(Vector2(588, 582), "右键    移动 / 攻击对手", 14)
	_text(Vector2(588, 607), "A 攻击  /  Q 训练震击", 14)
	_text(Vector2(588, 632), "方向键 / 滚轮  控制镜头", 14)
	_text(Vector2(588, 657), "空格    返回单位", 14)
	_text(Vector2(588, 692), "小地图：左键看 / 右键走", 12, muted)
	_text(Vector2(794, 549), "物品栏", 15, gold)
	_text(Vector2(994, 548), "单位指令", 14, gold)
	var message: String = "选择移动目的地 · 左键确认" if battle.move_mode else notice
	draw_rect(Rect2(194, 484, 1086, 37), Color("20281f"))
	_text(Vector2(207, 507), message, 14, Color("e3e1bc"))
	_text(Vector2(864, 507), "开发场景 · 非原版地图 / 数值 / 美术", 12, Color("d4d4b6"))

func _bar(rect: Rect2, color: Color, label: String, ratio: float) -> void:
	draw_rect(rect, Color("101911"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0, 1), rect.size.y)), color)
	draw_rect(rect, Color("121812"), false, 1)
	_text(rect.position + Vector2(28, 10), label, 10)
