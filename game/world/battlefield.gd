extends Node3D
## 场景装配入口：组合规则、地形、视图、输入和界面，避免承担具体算法。

const Simulation = preload("res://simulation/training_world.gd")
const Terrain = preload("res://world/terrain_builder.gd")
const CameraRig = preload("res://presentation/camera_rig.gd")
const UnitView = preload("res://presentation/unit_view.gd")
const Geometry = preload("res://presentation/mesh_factory.gd")
const InputAdapter = preload("res://input/battle_input.gd")
const Hud = preload("res://ui/classic_hud.gd")
var simulation := Simulation.new()
var camera_rig := CameraRig.new()
var hero := UnitView.new()
var enemy := UnitView.new()
var input_adapter := InputAdapter.new()
var geometry := Geometry.new()
var destination: MeshInstance3D
var spell_ring: MeshInstance3D
var spell_remaining := 0.0
var level_notice := ""
var level_notice_remaining := 0.0
var hud: Control
var selected := true
var move_mode := false
var paused := false
var army: Node3D
var focus: Vector3:
	get: return camera_rig.focus
	set(value): camera_rig.focus = value
var edge_scroll: bool:
	get: return camera_rig.edge_scroll
	set(value): camera_rig.edge_scroll = value

func _ready() -> void:
	var terrain := Terrain.new()
	add_child(terrain)
	terrain.build(simulation)
	if get_tree().get_meta("lane_mode", "--lanes" in OS.get_cmdline_user_args()):
		simulation.start_match()
		army = preload("res://presentation/army_view.gd").new()
		add_child(army)
		army.buildings = terrain.building_views
	add_child(hero)
	hero.build(Color("6f98ac"))
	add_child(enemy)
	enemy.build(Color("b87960"))
	enemy.visible = simulation.match_state == null
	add_child(camera_rig)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.battle = self
	layer.add_child(hud)
	destination = geometry.cylinder(self, Vector3.ZERO, 0.75, 0.04, Color("bfe673"))
	destination.visible = false
	var effect := TorusMesh.new()
	effect.inner_radius = 4.8
	effect.outer_radius = 5.0
	spell_ring = geometry.mesh(self, effect, Vector3.ZERO, Color("e8b85d"))
	spell_ring.visible = false
	simulation.combat.combat_event.connect(_on_combat_event)
	simulation.progression.leveled.connect(_on_level_up)
	_sync_views(0)
	if "--smoke-test" in OS.get_cmdline_user_args(): call_deferred("_smoke_test")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-path="):
			call_deferred("_capture", argument.trim_prefix("--capture-path="))

func _physics_process(delta: float) -> void:
	if paused: return
	level_notice_remaining = maxf(0, level_notice_remaining - delta)
	simulation.step(delta)
	_sync_views(delta)
	if simulation.path.is_empty(): destination.visible = false
	spell_remaining = maxf(0, spell_remaining - delta)
	spell_ring.visible = spell_remaining > 0
	spell_ring.scale = Vector3.ONE * (1 - spell_remaining)

func _sync_views(delta: float) -> void:
	var target := simulation.current_target()
	hero.sync(simulation.combat.player, selected, delta, target.position if target != null else simulation.position)
	if army != null: army.sync(simulation.combat, delta)
	enemy.sync(simulation.combat.enemy, false, delta, simulation.position)

func _process(delta: float) -> void:
	camera_rig.update(delta, paused)
	hud.sync_state()
	hud.queue_redraw()

func ground_at(screen: Vector2) -> Variant:
	return camera_rig.ground_at(screen)

func issue_move(at: Vector3) -> void:
	if not selected or paused: return
	if simulation.submit_move(at):
		destination.position = Vector3(clampf(roundf(at.x), -48, 48), 0.15, clampf(roundf(at.z), -48, 48))
		destination.visible = true
		hud.notice = "移动指令已下达"
	else:
		hud.notice = "当前无法移动，请检查单位状态或目标位置"
	move_mode = false

func command(action: String) -> void:
	if action == "shop":
		if not paused:
			if hud.shop.visible: hud.shop.close()
			else: hud.shop.open()
		return
	if hud.shop.visible and action == "menu":
		hud.shop.close()
		return
	if action in ["lanes", "training"]:
		get_tree().set_meta("lane_mode", action == "lanes")
		get_tree().reload_current_scene()
		return
	if paused and action not in ["menu", "edge", "quit"]: return
	if not selected and action in ["move", "stop", "hold", "attack", "strike"]: return
	match action:
		"center":
			selected = true
			focus = simulation.position
		"move": move_mode = simulation.combat.player.alive()
		"stop", "hold":
			simulation.submit_stop(action == "hold")
			move_mode = false
		"attack":
			var reason := simulation.submit_attack()
			hud.notice = "追击目标，到达射程后自动攻击" if reason.is_empty() else reason
			move_mode = false
		"strike":
			var reason := simulation.submit_strike()
			hud.notice = "训练震击：造成 80 伤害并眩晕 1.5 秒" if reason.is_empty() else reason
			move_mode = false
		"edge": edge_scroll = not edge_scroll
		"menu":
			paused = not paused
			hud.set_paused(paused)
			move_mode = false
		"quit": get_tree().quit()

func _on_combat_event(event: Dictionary) -> void:
	if army != null:
		army.react(event)
		if event.type in ["damage", "swing", "death", "respawn"] and event.get("target", event.actor) not in ["player", "enemy"]:
			return
	if event.type == "damage":
		var view := hero if event.target == "player" else enemy
		view.react(event)
	elif event.type == "swing":
		var view := hero if event.actor == "player" else enemy
		view.react(event)
	elif event.type == "spell":
		spell_remaining = 0.45
		spell_ring.position = event.position + Vector3(0, 0.16, 0)
	elif event.type == "death":
		hud.notice = "击败训练对手，获得 50 训练金币" if event.actor == "enemy" else "单位倒下，5 秒后在出生点复活"
	elif event.type == "respawn":
		hud.notice = "训练对手已复活" if event.actor == "enemy" else "单位已复活，生命与魔法已恢复"

func _input(event: InputEvent) -> void:
	input_adapter.keyboard(self, event)

func _on_level_up(level: int) -> void:
	level_notice = "升至 %d 级：攻击 +6，生命上限 +80，魔法上限 +30" % level
	level_notice_remaining = 3.0

func _unhandled_input(event: InputEvent) -> void:
	input_adapter.pointer(self, event)

func _smoke_test() -> void:
	var suite: RefCounted = load("res://tests/scenario_smoke.gd").new()
	await suite.run(self)

func _capture(path: String) -> void:
	for frame in range(12): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("截图：%s，结果=%s" % [path, result])
	if "--capture-and-quit" in OS.get_cmdline_user_args():
		get_tree().quit(0 if result == OK else 1)
