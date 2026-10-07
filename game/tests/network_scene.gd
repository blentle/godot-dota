extends SceneTree
## 独立图形客户端进程：真实商店点击、远程移动、菜单不停服、心跳与断线冻结。

var flow: Node
var output_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	flow = preload("res://bootstrap/network_flow.gd").new()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="): flow.port = int(argument.trim_prefix("--port="))
		if argument.begins_with("--output-dir="): output_dir = argument.trim_prefix("--output-dir=")
	root.add_child(flow)
	if not await _until(func() -> bool: return flow.phase == "playing", 8000): return
	var world: RefCounted = flow.world
	var battle: Node3D = flow.battle
	if not _check(battle.remote and not world.has_method("start_match"), "图形客户端不能创建本地规则世界"): return
	var before: int = world.combat.gold
	battle.command("shop")
	var button: Button = battle.hud.shop.buy_buttons.blade
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	if not _check(world.combat.gold == before and world.economy.slots.count("blade") == 0, "购买发送后不能本地扣费"): return
	if not await _until(func() -> bool: return world.economy.slots.count("blade") == 1, 3000): return
	if not _check(world.combat.gold < before and battle.hud.inventory_buttons[0].text == "短剑", "服务器装备应同步到 HUD"): return
	battle.hud.shop.close()
	var start: Vector3 = world.position
	battle.issue_move(start + Vector3(4, 0, 0))
	if not _check(world.position == start, "移动命令不能先修改客户端位置"): return
	if not await _until(func() -> bool: return world.position.x > start.x + 1, 3000): return
	battle.command("menu")
	var previous_tick: int = world.tick
	if not await _until(func() -> bool: return world.tick >= previous_tick + 12, 3000): return
	if not _check(battle.hud.menu.visible and battle.paused, "联网菜单应保持开启且继续消费快照"): return
	battle.command("menu")
	battle.command("summon")
	if not await _until(func() -> bool: return not world.summons.active_id.is_empty(), 3000): return
	if not await _until(func() -> bool: return battle.army.views.has(world.summons.active_id), 2000): return
	await _capture("network-playing.png")
	# 空闲期限按真实时钟检查，不能用受模拟负载影响的游戏计时替代。
	var idle_started := Time.get_ticks_msec()
	if not await _until(func() -> bool: return Time.get_ticks_msec() - idle_started >= 11000, 14000): return
	if not _check(flow.phase == "playing", "心跳必须保持空闲会话"): return
	if not await _until(func() -> bool: return flow.phase == "failed", 10000): return
	var frozen: Vector3 = world.position
	if not _check(not world.submit_move(frozen + Vector3.ONE) and not battle.is_processing_input(), "断线必须拒绝命令并关闭战场输入"): return
	await _capture("network-disconnected.png")
	flow.leave()
	await process_frame
	await process_frame
	var offline := root.get_child(root.get_child_count() - 1)
	if not _check(offline.phase == "selection", "断线后必须可以返回离线选人"): return
	print("NETWORK_SCENE_PASS：远程画面、购买、移动、召唤、菜单、心跳及断线退出。")
	quit(0)

func _until(condition: Callable, timeout: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout
	while not condition.call():
		if Time.get_ticks_msec() > deadline: return _check(false, "等待超时，阶段=" + flow.phase)
		await process_frame
	await process_frame
	return true

func _capture(name: String) -> void:
	if output_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	if not _check(root.get_texture().get_image().save_png(output_dir.path_join(name)) == OK, "截图保存失败"): return

func _check(value: bool, reason: String) -> bool:
	if not value:
		push_error(reason)
		quit(1)
	return value
