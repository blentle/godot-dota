extends Node
## 本机联网会话：首个快照就绪后创建战场，失联后冻结画面并提供退出入口。

const Style = preload("res://ui/session_style.gd")
var port := 27883
var client := preload("res://network/dev_client.gd").new()
var world: RefCounted
var battle: Node3D
var phase := "connecting"
var panel: Control
var status: Label
var layer := CanvasLayer.new()
var last_seen := 0
var last_ping := 0
var started := 0

func _ready() -> void:
	layer.layer = 4
	add_child(layer)
	world = preload("res://network/remote_world.gd").new(client)
	client.received.connect(_receive)
	started = Time.get_ticks_msec()
	last_seen = started
	_show_status("正在连接本机开发服务器…")
	if port < 1024 or port > 65535 or client.start(port) != OK: _fail("无法连接：请检查端口和开发服务器")

func _process(_delta: float) -> void:
	if phase in ["failed", "leaving"]: return
	client.poll()
	var now := Time.get_ticks_msec()
	if phase == "connecting" and client.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		phase = "loading"
		var hello: Dictionary = preload("res://network/dev_protocol.gd").identity()
		hello.merge({"type": "hello", "profile": "guardian"})
		client.send(hello)
	if phase == "loading" and now - started > 8000: _fail("服务器未完成装载，请返回后重试")
	elif phase == "connecting" and now - started > 8000: _fail("连接超时，请先启动本机开发服务器")
	elif phase in ["playing", "result"]:
		if client.peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED or now - last_seen > 5000:
			_fail("与服务器的连接已断开，本局已停止接收操作")
		elif now - last_ping >= 1000:
			last_ping = now
			client.send({"type": "ping"})

func _receive(message: Dictionary) -> void:
	last_seen = Time.get_ticks_msec()
	if message.get("type") == "error":
		_fail("服务器拒绝连接或操作：" + str(message.get("code", "UNKNOWN")))
	elif message.get("type") == "snapshot":
		if phase == "loading": _enter_battle()
		if phase == "playing" and world.finished(): _show_result()

func _enter_battle() -> void:
	_clear_panel()
	phase = "playing"
	battle = preload("res://world/battlefield.gd").new()
	battle.remote = true
	battle.simulation = world
	battle.session_requested.connect(func(action: String) -> void:
		if action == "selection": leave())
	world.feedback.connect(func(message: String) -> void:
		if is_instance_valid(battle):
			battle.hud.notice = message
			if battle.hud.shop.visible: battle.hud.shop.feedback.text = message)
	add_child(battle)
	battle.focus = world.position

func _show_result() -> void:
	phase = "result"
	_freeze()
	panel = preload("res://ui/result_screen.gd").new()
	panel.snapshot = world.result_snapshot()
	panel.action_requested.connect(func(_action: String) -> void: leave())
	layer.add_child(panel)
	panel.restart_button.disabled = true
	panel.restart_button.text = "联网重开尚未开放"

func _freeze() -> void:
	world.disable()
	if not is_instance_valid(battle): return
	battle.paused = true
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.set_process_input(false)
	battle.set_process_unhandled_input(false)
	battle.hud.hide()

func _fail(message: String) -> void:
	print("网络会话结束：", message)
	phase = "failed"
	client.close()
	_freeze()
	_show_status(message)

func _show_status(message: String) -> void:
	_clear_panel()
	panel = Control.new()
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Style.background(panel)
	Style.label(panel, "DotA 6.83d / 本机联网验证", Vector2(80, 90), 26, Color("c6ab70"))
	status = Style.label(panel, message, Vector2(80, 210), 22)
	Style.label(panel, "单席位开发对局 · 服务器决定移动、战斗和资源", Vector2(80, 265), 16)
	var back: Button = Style.button(panel, "返回离线角色选择", Rect2(80, 350, 280, 52))
	back.pressed.connect(leave)
	back.grab_focus()

func _clear_panel() -> void:
	if is_instance_valid(panel):
		layer.remove_child(panel)
		panel.queue_free()
	panel = null

func leave() -> void:
	phase = "leaving"
	client.close()
	world.disable()
	var offline := preload("res://bootstrap/client_flow.gd").new()
	get_parent().add_child(offline)
	queue_free()

func _exit_tree() -> void:
	client.close()
