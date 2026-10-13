extends SceneTree
## 外部工具终止并重启服务器；客户端凭原令牌恢复角色和已确认交易。

var flow: Node
var index := 0
var release_file := ""
var players := 2

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	flow = preload("res://bootstrap/network_flow.gd").new()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="): flow.port = int(argument.trim_prefix("--port="))
		if argument.begins_with("--index="): index = int(argument.trim_prefix("--index="))
		if argument.begins_with("--release-file="): release_file = argument.trim_prefix("--release-file=")
		if argument.begins_with("--players="): players = int(argument.trim_prefix("--players="))
	root.add_child(flow)
	if not await _until(func() -> bool: return flow.phase == "playing", 12000): return
	var world: RefCounted = flow.world
	var entity: String = world.combat.player.id
	var item: String = ["blade", "charm", "boots"][index % 3]
	world.submit_buy(item)
	if not await _until(func() -> bool: return world.economy.slots.has(item) and world.pending.is_empty(), 5000): return
	# 每个进程使用不同序号，防止恢复时串用其他席位的确认记录。
	for ignored in range(index): world.submit_stop(true)
	if not await _until(func() -> bool: return world.pending.is_empty(), 5000): return
	var inventory: Array = world.economy.slots.duplicate()
	var elapsed: float = world.elapsed
	print("RESTART_READY")
	if not await _until(func() -> bool: return flow.phase == "reconnecting", 15000): return
	print("RESTART_WAITING")
	if not await _until(func() -> bool: return flow.phase == "playing", 25000): return
	if not _check(world.combat.player.id == entity and world.economy.slots == inventory, "重启后角色或已确认装备丢失"): return
	if not _check(world.sequence == index + 1 and world.elapsed >= elapsed - 1.1, "重启未恢复序号或回滚超过保存间隔"): return
	world.submit_buy("vest")
	if not await _until(func() -> bool: return world.economy.slots.has("vest") and world.pending.is_empty(), 5000): return
	if not _check(world.sequence == index + 2 and world.economy.slots.count("vest") == 1, "恢复后下一笔交易应只执行一次"): return
	if not await _until(func() -> bool: return flow.client.latest.get("connected_players", 0) == players, 12000): return
	print("RESTART_RESTORED")
	# 所有进程恢复并交易成功后，外部协调器才放行离场。
	if not release_file.is_empty():
		if not await _until(func() -> bool: return FileAccess.file_exists(release_file), 15000): return
	flow.phase = "leaving"
	await flow.client.leave()
	if not _check(flow.client.departed, "重启后应能确认离场"): return
	print("RESTART_CLIENT_PASS")
	quit(0)

func _until(condition: Callable, timeout: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout
	while not condition.call():
		if flow.phase == "failed" or Time.get_ticks_msec() > deadline: return _check(false, "服务器重启场景失败：" + flow.phase)
		await process_frame
	return true

func _check(value: bool, reason: String) -> bool:
	if not value:
		push_error(reason)
		quit(1)
	return value
