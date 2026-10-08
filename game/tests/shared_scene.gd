extends SceneTree
## 两个独立图形客户端执行相同脚本；同时观察双方移动和召唤，并导出共同 tick 的世界摘要。

var flow: Node
var signatures: Dictionary = {}
var output_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	flow = preload("res://bootstrap/network_flow.gd").new()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="): flow.port = int(argument.trim_prefix("--port="))
		if argument.begins_with("--output-dir="): output_dir = argument.trim_prefix("--output-dir=")
	flow.client.received.connect(_record)
	root.add_child(flow)
	if not await _until(func() -> bool: return flow.phase == "playing", 10000): return
	var world: RefCounted = flow.world
	var battle: Node3D = flow.battle
	var team: int = world.combat.player.team
	var other_id := "player_2" if team == 0 else "player"
	if not await _until(func() -> bool: return world.combat.units.has(other_id) and battle.army.views.has(other_id), 10000): return
	if not _check(battle.shared_network and world.combat.player.id != other_id, "必须显示另一玩家但只控制自己的英雄"): return
	var item := "blade" if team == 0 else "vest"
	battle.command("shop")
	await _click(battle.hud.shop.buy_buttons[item])
	if not await _until(func() -> bool: return world.economy.slots.has(item), 4000): return
	if not _check(world.economy.slots.count("") == 5, "不能看到另一玩家背包中的装备"): return
	battle.hud.shop.close()
	var start: Vector3 = world.position
	var direction := 1 if team == 0 else -1
	battle.issue_move(start + Vector3(direction * 4, 0, 0))
	if not await _until(func() -> bool: return world.position.distance_to(start) > 1, 4000): return
	var other_start := Vector3(32, 0, -30) if team == 0 else Vector3(-32, 0, 30)
	if not await _until(func() -> bool: return world.combat.units[other_id].position.distance_to(other_start) > 1, 4000): return
	battle.command("summon")
	if not await _until(func() -> bool: return world.combat.units.has("player_summon_1") and world.combat.units.has("player_2_summon_1"), 5000): return
	if not await _until(func() -> bool: return battle.army.views.has(world.summons.active_id), 3000): return
	# 给两个接收者留出共同快照窗口；只观察，不在客户端修改规则。
	var until := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < until: await process_frame
	if not output_dir.is_empty():
		await RenderingServer.frame_post_draw
		if not _check(root.get_texture().get_image().save_png(output_dir.path_join("shared-team-%d.png" % team)) == OK, "双玩家截图失败"): return
	print("SHARED_SIGNATURES " + JSON.stringify({"team": team, "states": signatures}))
	print("SHARED_SCENE_PASS：阵营=%d，自身控制、私有背包、共同世界、另一玩家视图及双方召唤。" % team)
	flow.client.close()
	quit(0)

func _record(message: Dictionary) -> void:
	if message.get("type") == "snapshot" and message.get("mode") == "shared":
		signatures[str(int(message.tick))] = JSON.stringify(message.units).sha256_text()

func _click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func _until(condition: Callable, timeout: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout
	while not condition.call():
		if Time.get_ticks_msec() > deadline: return _check(false, "同局场景等待超时：" + flow.phase)
		await process_frame
	return true

func _check(value: bool, reason: String) -> bool:
	if not value:
		push_error(reason)
		quit(1)
	return value
