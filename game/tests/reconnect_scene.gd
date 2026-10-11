extends SceneTree
## 真实客户端恢复原席位，也可作为保持在线的观察者；恢复后验证原席位与交易状态。

var flow: Node
var observer := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	flow = preload("res://bootstrap/network_flow.gd").new()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="): flow.port = int(argument.trim_prefix("--port="))
		if argument == "--observer": observer = true
	root.add_child(flow)
	if not await _until(func() -> bool: return flow.phase == "playing", 12000): return
	if observer:
		var before: float = flow.world.elapsed
		var finish := Time.get_ticks_msec() + 35000
		while Time.get_ticks_msec() < finish:
			if not _check(flow.phase == "playing", "另一玩家断网不应冻结在线者"): return
			await process_frame
		if not _check(flow.world.elapsed > before + 25, "在线世界必须持续推进"): return
		print("RECONNECT_OBSERVER_PASS")
	else:
		var world: RefCounted = flow.world
		var entity: String = world.combat.player.id
		world.submit_buy("blade")
		if not await _until(func() -> bool: return world.economy.slots.has("blade") and world.pending.is_empty(), 5000): return
		print("PARTITION_READY")
		await create_timer(1).timeout
		# 转发器已开始全断：该请求无法到达服务器，恢复时不得自动重放。
		world.submit_buy("vest")
		if not await _until(func() -> bool: return flow.phase == "reconnecting", 10000): return
		if not _check(not world.economy.enabled and world.closed, "重连时必须冻结本地规则入口"): return
		if not await _until(func() -> bool: return flow.phase == "playing", 25000): return
		if not _check(world.combat.player.id == entity and world.economy.slots.count("blade") == 1, "必须恢复原英雄和原装备"): return
		if not _check(not world.economy.slots.has("vest") and world.pending.is_empty() and world.sequence == 1, "未送达意图必须丢弃并恢复权威序号"): return
		world.submit_buy("vest")
		if not await _until(func() -> bool: return world.economy.slots.has("vest") and world.pending.is_empty(), 5000): return
		if not _check(world.economy.slots.count("vest") == 1 and world.sequence == 2, "恢复后的下一笔交易必须只执行一次"): return
		var before: Vector3 = world.position
		flow.battle.issue_move(before + Vector3(3 if world.combat.player.team == 0 else -3, 0, 0))
		if not await _until(func() -> bool: return world.position.distance_to(before) > 1, 5000): return
		print("RECONNECT_CLIENT_PASS")
	flow.phase = "leaving"
	await flow.client.leave()
	quit(0)

func _until(condition: Callable, timeout: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout
	while not condition.call():
		if flow.phase == "failed" or Time.get_ticks_msec() > deadline:
			return _check(false, "重连场景等待失败：" + flow.phase)
		await process_frame
	return true

func _check(value: bool, reason: String) -> bool:
	if not value:
		push_error(reason)
		quit(1)
	return value
