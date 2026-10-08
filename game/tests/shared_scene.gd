extends SceneTree
## 多个独立图形客户端执行相同脚本；观察所有英雄和召唤，并导出共同 tick 的世界摘要。

var flow: Node
var signatures: Dictionary = {}
var output_dir := ""
var required_players := 2
var assigned_slot := -1

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
	if not await _until(_all_heroes_visible, 10000): return
	var own_id := "player" if assigned_slot == 0 else "player_%d" % (assigned_slot + 1)
	if not _check(battle.shared_network and world.combat.player.id == own_id, "必须只控制服务端分配的英雄"): return
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
	battle.command("summon")
	if not await _until(_all_summons_visible, 5000): return
	if not await _until(func() -> bool: return battle.army.views.has(world.summons.active_id), 3000): return
	# 给两个接收者留出共同快照窗口；只观察，不在客户端修改规则。
	var until := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < until: await process_frame
	if not output_dir.is_empty():
		await RenderingServer.frame_post_draw
		if not _check(root.get_texture().get_image().save_png(output_dir.path_join("shared-slot-%d.png" % assigned_slot)) == OK, "多人截图失败"): return
	print("SHARED_SIGNATURES " + JSON.stringify({"team": team, "slot": assigned_slot, "entity": own_id, "states": signatures}))
	print("SHARED_SCENE_PASS：阵营=%d，自身控制、私有背包、共同世界、所有玩家视图及共同召唤。" % team)
	flow.client.close()
	quit(0)

func _record(message: Dictionary) -> void:
	if message.get("type") == "welcome":
		required_players = int(message.get("required_players", 2))
		assigned_slot = int(message.get("slot", -1))
	if message.get("type") == "snapshot" and message.get("mode") == "shared" and message.elapsed > 0:
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

func _all_heroes_visible() -> bool:
	for slot in range(required_players):
		var id := "player" if slot == 0 else "player_%d" % (slot + 1)
		if not flow.world.combat.units.has(id): return false
		if slot != assigned_slot and not flow.battle.army.views.has(id): return false
	return true

func _all_summons_visible() -> bool:
	for slot in range(required_players):
		var id := "player" if slot == 0 else "player_%d" % (slot + 1)
		if not flow.world.combat.units.has(id + "_summon_1"): return false
	return true
