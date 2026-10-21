extends "res://ui/war3/scripts/hud.gd"
## 原生 4:3 HUD：布局由原始 FDF 及静态场景给出，脚本仅更新美术和状态。

signal command_requested(action: String)
signal learn_requested
const Art = preload("res://ui/war3/scripts/classic_art.gd")
const Catalog = preload("res://presentation/classic/hero_catalog.gd")
var visual_hero: Dictionary = Catalog.find("Hmbr")
@export_enum("nightelf", "undead", "human") var console_race := "nightelf"

func _ready() -> void:
	super._ready()
	$Console.texture = Art.texture("console-%s.png" % console_race)
	$Clock.texture = Art.texture("clock-%s.png" % console_race)
	$BottomBlack.texture = Art.texture("black.png")
	$MapBlack.texture = Art.texture("black.png")
	$Resources/GoldIcon.texture = Art.texture("ui/feedback/resources/resourcegold.png")
	$Resources/LumberIcon.texture = Art.texture("ui/feedback/resources/resourcelumber.png")
	$HeroPanel/AttackIcon.texture = Art.texture("ui/widgets/console/human/infocard-attack-hero.png")
	$HeroPanel/ArmorIcon.texture = Art.texture("ui/widgets/console/human/infocard-armor-hero.png")
	$HeroPanel/Portrait.set_hero(visual_hero)
	for index in range(4):
		var action: String = ["move", "stop", "hold", "patrol"][index]
		var button: Control = $HeroPanel.get_node("Command%d" % index)
		button.set_icon(Art.icon(["btnmove", "btnstop", "btnholdposition", "btnpatrol"][index]), Art.highlight(),
			Art.icon(["btnmove", "btnstop", "btnholdposition", "btnpatrol"][index], true),
			["移动 M", "停止 S", "保持 H", "巡逻（训练未实现）"][index], "下达单位指令")
		button.activated.connect(func(): command_requested.emit(action))
		_bind_tip(button)
	$HeroPanel/Attack.set_icon(Art.icon("btnattack"), Art.highlight(), Art.icon("btnattack", true), "攻击 A", "攻击当前目标")
	$HeroPanel/Attack.activated.connect(func(): command_requested.emit("attack"))
	_bind_tip($HeroPanel/Attack)
	$HeroPanel/Learn.set_icon(Art.icon("btnskillz"), Art.highlight(), Art.icon("btnskillz", true), "英雄技能", "选择要升级的训练技能")
	$HeroPanel/Learn.activated.connect(func(): learn_requested.emit())
	_bind_tip($HeroPanel/Learn)
	$Tooltip/Background.texture = Art.region("tooltip.png", 320, 160)
	$Multiboard/Background.texture = Art.region("multiboard.png", 340, 268)
	$HeroPanel/Experience/Background.texture = Art.texture("black.png")
	$HeroPanel/Experience/Clip/Fill.texture = Art.texture("ui/feedback/xpbar/human-bigbar-fill.png")
	for index in range(4):
		var button: Control = get_node("TopMenu%d" % index)
		button.set_icon(Art.menu(0, console_race), Art.menu(1, console_race), Art.menu(2, console_race), ["任务", "菜单", "盟友", "聊天"][index], "原版顶栏位置")
		button.get_node("Text").text = ["任务 F9", "菜单 F10", "盟友 F11", "聊天 F12"][index]
		button.activated.connect(func(): command_requested.emit("menu" if index == 1 else "info"))
	$ScoreToggle.set_icon(Art.menu(0, console_race), Art.menu(1, console_race), Art.menu(2, console_race), "计分板", "展开或收起计分板")
	$ScoreToggle.activated.connect(func(): $Multiboard.visible = not $Multiboard.visible)
	$ScoreToggle.get_node("Text").text = "计分板 +/-"
	$Multiboard.hide()
	for index in range(10):
		$Multiboard.get_node("Row%d/Line" % index).hide()
	for index in range(5):
		var cell: Control = $TeamPortraits.get_node("Portrait%d" % index)
		cell.get_node("Frame").hide()

func _bind_tip(button: Control) -> void:
	button.tooltip_entered.connect($Tooltip.request)
	button.tooltip_exited.connect($Tooltip.cancel)

func apply_state(data: Dictionary) -> void:
	# 校对模式的头像图标也来自同一地图条目，死亡时换预制 DISBTN。
	var icon := str(visual_hero.icon).replace(".blp", ".png")
	var dead := icon.replace("/commandbuttons/btn", "/commandbuttonsdisabled/disbtn")
	for list in [data.get("players", []), data.get("team", [])]:
		if not list.is_empty():
			list[0].portrait = Art.texture(icon)
			list[0].dead_portrait = Art.texture(dead)
	super.apply_state(data)
	$HeroPanel/Portrait.set_hero(visual_hero)
	$HeroPanel/Damage.text = "%d - %d" % [data.hero.get("damage", 0), data.hero.get("damage", 0)]
	$HeroPanel/Armor.text = "—"
	var ratio: float = clampf(float(data.hero.get("hp", 0)) / maxf(1, float(data.hero.get("max_hp", 1))), 0, 1)
	$HeroPanel/Health/Value.self_modulate = Color(minf(1, 2 - ratio*2), minf(1, ratio*2), 0)
	# 原版专名与英雄称号分行；校对模式用原始配置最常见专名，不伪造随机选名。
	$HeroPanel/HeroName.text = str(visual_hero.get("display_name", visual_hero.name))
	$HeroPanel/Class.text = "第%d级 %s" % [int(data.hero.get("level", 1)), str(visual_hero.name)]
	var blocked: bool = data.get("commands_blocked", false)
	for index in range(4): $HeroPanel.get_node("Command%d" % index).set_state(0, blocked or index == 3)
	$HeroPanel/Attack.set_state(0, blocked)
	$HeroPanel/Learn.set_state(0, blocked or int(data.hero.get("skill_points", 0)) <= 0)
