extends Control
## 训练配置选择；不把开发角色包装为原版英雄。

signal start_requested(profile: String, mode: String)

const Style = preload("res://ui/session_style.gd")
const Profiles = preload("res://simulation/hero_profiles.gd")
var selected_profile := "guardian"
var selected_mode := "lanes"
var cards: Dictionary = {}
var mode_buttons: Dictionary = {}
var start_button: Button
var detail: Label

func _ready() -> void:
	Style.background(self)
	Style.label(self, "DotA 6.83d  /  离线开发演练", Vector2(64, 40), 18, Style.GOLD)
	Style.label(self, "选择训练角色", Vector2(64, 79), 34)
	Style.label(self, "以下是机制验证配置，共用 Q / W / E 训练技能；不是正式英雄。", Vector2(64, 133), 17, Style.MUTED)
	var index := 0
	for id in Profiles.PROFILES:
		var profile: Dictionary = Profiles.PROFILES[id]
		var x := 64 + index * 392
		var card := Style.button(self, "", Rect2(x, 190, 368, 295))
		card.toggle_mode = true
		card.pressed.connect(func(): select_profile(id))
		cards[id] = card
		# 子标签忽略鼠标，整块卡片保持单一点击与焦点目标。
		var title := Style.label(card, profile.name, Vector2(24, 28), 27, Color(profile.color).lightened(0.2))
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var text := "%s\n\n生命 %.0f    魔法 %.0f\n攻击 %.0f    射程 %.1f\n攻击间隔 %.1f 秒\n\n开发参数 · 临时外观" % [profile.description, profile.hp, profile.mana, profile.damage, profile.range, profile.interval]
		var body := Style.label(card, text, Vector2(24, 86), 18)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		index += 1
	for mode in ["lanes", "training"]:
		var x := 64 if mode == "lanes" else 314
		var mode_button := Style.button(self, "三路兵线演练" if mode == "lanes" else "单对手训练", Rect2(x, 517, 234, 46))
		mode_button.toggle_mode = true
		mode_button.pressed.connect(func(): select_mode(mode))
		mode_buttons[mode] = mode_button
	detail = Style.label(self, "", Vector2(64, 590), 17, Style.MUTED)
	start_button = Style.button(self, "开始演练", Rect2(924, 591, 292, 58))
	start_button.pressed.connect(func(): start_requested.emit(selected_profile, selected_mode))
	var exit_button := Style.button(self, "退出", Rect2(1096, 46, 120, 40))
	exit_button.pressed.connect(func(): get_tree().quit())
	select_profile(selected_profile)
	select_mode(selected_mode)
	cards[selected_profile].grab_focus()

func select_profile(id: String) -> void:
	if not Profiles.PROFILES.has(id): return
	selected_profile = id
	for key in cards: cards[key].set_pressed_no_signal(key == id)

func select_mode(mode: String) -> void:
	if mode not in ["lanes", "training"]: return
	selected_mode = mode
	for key in mode_buttons: mode_buttons[key].set_pressed_no_signal(key == mode)
	detail.text = "摧毁敌方三塔与基地后结算；初始 300 金币。" if mode == "lanes" else "与自动复活的训练对手练习；此模式没有胜负结算。"
