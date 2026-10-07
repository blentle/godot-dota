extends Node
## 客户端会话状态机：选人、运行、结算；重开必须创建新的规则世界。

const Selection = preload("res://ui/selection_screen.gd")
const Result = preload("res://ui/result_screen.gd")
const Battlefield = preload("res://world/battlefield.gd")
var phase := "selection"
var profile := "guardian"
var mode := "lanes"
var ui := CanvasLayer.new()
var screen: Control
var battle: Node3D

func _ready() -> void:
	ui.layer = 2
	add_child(ui)
	show_selection()
	var args := OS.get_cmdline_user_args()
	if "--smoke-test" in args or "--training" in args or "--lanes" in args:
		launch(profile, "lanes" if "--lanes" in args else "training")

func show_selection() -> void:
	_clear_screen()
	_drop_battle()
	phase = "selection"
	screen = Selection.new()
	screen.selected_profile = profile
	screen.selected_mode = mode
	screen.start_requested.connect(_start_requested)
	ui.add_child(screen)

func _start_requested(id: String, selected_mode: String) -> void:
	if phase == "selection": launch(id, selected_mode)

func launch(id: String, selected_mode: String) -> bool:
	if selected_mode not in ["lanes", "training"]: return false
	var next := Battlefield.new()
	var rejection: String = next.simulation.configure_hero(id)
	if not rejection.is_empty():
		next.free()
		return false
	_clear_screen()
	_drop_battle()
	profile = id
	mode = selected_mode
	phase = "playing"
	get_tree().set_meta("lane_mode", mode == "lanes")
	battle = next
	battle.session_requested.connect(_route)
	add_child(battle)
	return true

func _process(_delta: float) -> void:
	if phase != "playing" or battle == null or not battle.simulation.finished(): return
	phase = "result"
	battle.paused = true
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.set_process_input(false)
	battle.set_process_unhandled_input(false)
	battle.hud.hide()
	screen = Result.new()
	screen.snapshot = battle.simulation.result_snapshot()
	screen.action_requested.connect(_route)
	ui.add_child(screen)

func _route(action: String) -> void:
	match action:
		"selection": show_selection()
		"restart": launch(profile, mode)
		"lanes", "training": launch(profile, action)

func _clear_screen() -> void:
	if is_instance_valid(screen):
		ui.remove_child(screen)
		screen.queue_free()
	screen = null

func _drop_battle() -> void:
	if is_instance_valid(battle):
		remove_child(battle)
		battle.queue_free()
	battle = null
