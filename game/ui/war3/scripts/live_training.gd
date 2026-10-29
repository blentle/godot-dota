extends Control
## 经典 HUD 的真实离线训练接入；商店命令、地图及训练状态由独立组件处理。

const Snapshot = preload("res://ui/war3/scripts/training_snapshot.gd")
var adapter := Snapshot.new()
@onready var battle: Node3D = $Battle
@onready var hud: Control = $Interface/HUD
@onready var shop: Control = $Interface/Shop
@onready var upgrades: Control = $Interface/SkillUpgrades

func _ready() -> void:
	get_window().content_scale_size = Vector2i(1024, 768)
	get_window().size = Vector2i(1024, 768)
	get_window().unresizable = true
	get_viewport().msaa_2d = Viewport.MSAA_DISABLED
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	get_viewport().use_taa = false
	# 旧界面只保留命令兼容对象，不显示旧面板或接收键盘事件。
	battle.hud.hide()
	battle.set_process_input(false)
	upgrades.bind(battle, hud.get_node("Tooltip"))
	upgrades.state_changed.connect(_refresh)
	upgrades.result_reported.connect(func(message: String): $Interface/Notice.text = "训练技能：" + message)
	adapter.use_original_art = true
	hud.command_requested.connect(_hud_command)
	hud.learn_requested.connect(_toggle_learning)
	shop.battle = battle
	shop.state_changed.connect(_refresh)
	$Interface/ShopToggle.get_node("Text").text = "商店 B"
	$Interface/ShopToggle.activated.connect(_toggle_shop)
	hud.item_clicked.connect(_inspect_item)
	hud.skill_clicked.connect(_skill)
	hud.get_node("FloatingTextPool").camera = battle.camera_rig.camera
	battle.simulation.combat.combat_event.connect(_combat_event)
	# 将实际规则单位和地图装入固定 256×256 小地图视口。
	hud.get_node("Minimap/MapTexture").bind(battle)
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	hud.apply_state(adapter.read(battle.simulation, battle.selected, battle.paused or shop.visible))
	shop.sync_state()
	upgrades.blocked = shop.visible
	if shop.visible or battle.paused or not battle.selected: upgrades.hide()
	hud.get_node("HeroPanel/Portrait").paused = battle.paused
	hud.get_node("Clock").paused = battle.paused
	upgrades.sync_state()
	var minimap: Control = hud.get_node("Minimap/MapTexture")
	minimap.input_blocked = shop.visible
	if shop.visible: minimap.dragging = false
	minimap.refresh()
	var actor: RefCounted = battle.simulation.combat.player
	var enemy: RefCounted = battle.simulation.combat.enemy
	var targets: Array = []
	if actor.alive(): targets.append({"target": weakref(battle.hero), "hp": actor.hp, "max_hp": actor.max_hp})
	if enemy.alive() and battle.enemy.visible:
		targets.append({"target": weakref(battle.enemy), "hp": enemy.hp, "max_hp": enemy.max_hp})
	hud.get_node("FloatingTextPool").set_health_targets(targets)

func _skill(index: int) -> void:
	if not shop.visible and not upgrades.visible and index >= 0 and index < 3:
		battle.command(["strike", "area", "summon"][index])
		_refresh()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_B:
		_toggle_shop()
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_ESCAPE and upgrades.visible:
		upgrades.hide()
		get_viewport().set_input_as_handled()
		return
	if upgrades.visible and event.physical_keycode in [KEY_Q, KEY_W, KEY_E]:
		upgrades._upgrade({KEY_Q: "strike", KEY_W: "area", KEY_E: "summon"}[event.physical_keycode])
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_ESCAPE and shop.visible:
		shop.close()
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode in [KEY_ESCAPE, KEY_F10]:
		shop.close()
		battle.paused = not battle.paused
		$Interface/Notice.text = "训练已暂停 · Esc 继续" if battle.paused else ""
		_refresh()
		get_viewport().set_input_as_handled()
		return
	if shop.visible: return
	var actions := {KEY_Q: "strike", KEY_W: "area", KEY_E: "summon", KEY_F1: "center",
		KEY_S: "stop", KEY_H: "hold", KEY_A: "attack", KEY_M: "move"}
	if actions.has(event.physical_keycode):
		battle.command(actions[event.physical_keycode])
		get_viewport().set_input_as_handled()

func _combat_event(event: Dictionary) -> void:
	if event.type != "damage": return
	var view: Node3D = null
	if event.target == battle.simulation.combat.player.id: view = battle.hero
	elif event.target == "enemy": view = battle.enemy
	if view != null: hud.get_node("FloatingTextPool").damage(view, int(event.get("amount", 0)))

func _toggle_shop() -> void:
	if shop.visible: shop.close()
	else:
		hud.get_node("Tooltip").clear()
		shop.open()

func _inspect_item(index: int) -> void:
	hud.get_node("Tooltip").clear()
	shop.open(index)

func _hud_command(action: String) -> void:
	if shop.visible: return
	if action == "menu":
		battle.paused = not battle.paused
		_refresh()
	elif action == "info":
		$Interface/Notice.text = "经典原始美术校对中，训练规则尚未替换为正式英雄。"
	else: battle.command(action)

func _toggle_learning() -> void:
	if shop.visible or battle.paused or not battle.selected: return
	upgrades.visible = not upgrades.visible
	hud.get_node("Tooltip").clear()
