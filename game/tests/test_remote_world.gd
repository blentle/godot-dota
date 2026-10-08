extends SceneTree
## 验证远程门面的只读语义、快照替换和图形状态完整性。

class Connection extends RefCounted:
	signal received(message: Dictionary)
	var sent: Array[Dictionary] = []
	func send(message: Dictionary) -> Error:
		sent.append(message.duplicate(true))
		return OK

var failures := 0

func _initialize() -> void:
	var authority := preload("res://network/dev_authority.gd").new()
	var hello: Dictionary = preload("res://network/dev_protocol.gd").identity()
	hello.merge({"type": "hello", "profile": "guardian"})
	authority.receive(2, hello)
	var connection := Connection.new()
	var remote := preload("res://network/remote_world.gd").new(connection)
	var packet: Dictionary = JSON.parse_string(JSON.stringify(authority.snapshot(2)))
	remote.apply(packet)
	var position: Vector3 = remote.position
	var gold: int = remote.combat.gold
	_check(remote.submit_move(position + Vector3(3, 0, 0)), "远程移动应发送成功")
	remote.submit_buy("blade")
	remote.submit_skill("summon")
	remote.step(20)
	_check(remote.position == position and remote.combat.gold == gold and remote.economy.slots.count("") == 6, "本地不能推进移动或交易")
	_check(remote.summons.active_id.is_empty() and remote.combat.player.mana == 240, "本地不能创建召唤物或扣魔法")
	for command in connection.sent:
		connection.received.emit(authority.receive(2, command))
	authority.step()
	remote.apply(JSON.parse_string(JSON.stringify(authority.snapshot(2))))
	_check(remote.combat.gold == 200 and remote.economy.slots[0] == "blade", "服务端库存必须覆盖本地显示")
	_check(remote.combat.player.damage == 67 and remote.combat.player.summon_cooldown > 0, "派生属性和冷却必须同步")
	_check(remote.combat.units.has(remote.summons.active_id), "召唤物必须包含在快照中")
	_check(remote.pending.is_empty(), "确认应释放命令队列")
	remote.apply(packet)
	_check(remote.combat.gold == 200, "旧快照不能回退状态")
	var world: RefCounted = authority.session(2).world
	var tree: Dictionary = preload("res://simulation/terrain_layout.gd").trees()[0]
	_check(not world.submit_move(tree.position), "无界面服务器必须拒绝走进树木障碍")
	_check(not world.submit_move(world.combat.units.tower_1_0.position + Vector3(0.5, 0, 0.5)), "建筑障碍必须阻挡寻路")
	var player: RefCounted = world.combat.player
	var target: RefCounted = world.combat.units.tower_1_0
	world.combat.projectiles.launch(player, target)
	authority.step()
	remote.apply(JSON.parse_string(JSON.stringify(authority.snapshot(2))))
	_check(remote.combat.projectiles.active.size() == 1, "在途弹道必须同步给视图")
	world.submit_stop()
	var start: Vector3 = remote.position
	world.combat.player.position = start + Vector3(4, 0, 0)
	for index in range(6): authority.step()
	remote.apply(JSON.parse_string(JSON.stringify(authority.snapshot(2))))
	_check(remote.position == start, "新快照不能让单位位置跳变")
	remote.step(0.05)
	_check(absf(remote.position.distance_to(world.combat.player.position) - 2.0) < 0.01, "单位必须在快照窗口内逐步插值")
	remote.step(0.05)
	_check(remote.position.distance_to(world.combat.player.position) < 0.001, "插值窗口结束必须到达服务器位置")
	var events_seen: Array = []
	remote.combat.combat_event.connect(func(event: Dictionary) -> void: events_seen.append(event))
	world.combat.combat_event.emit({"type": "spell", "actor": "player", "position": Vector3(1.5, 0, 2.5)})
	authority.step()
	remote.apply(JSON.parse_string(JSON.stringify(authority.snapshot(2))))
	_check(events_seen.size() == 1 and events_seen[0].type == "spell" and events_seen[0].position.x == 1.5, "快照事件必须转发给表现层")
	world.combat.projectiles.launch(world.combat.units.tower_1_0, world.combat.player)
	authority.step()
	remote.apply(JSON.parse_string(JSON.stringify(authority.snapshot(2))))
	var flying: Dictionary = {}
	for shot in remote.combat.projectiles.active.values():
		if shot.speed > 0.0: flying = shot
	_check(not flying.is_empty() and flying.target == "player", "快照必须携带弹道目标与速度")
	var before: Vector3 = flying.position
	remote.step(0.1)
	_check(before.distance_to(flying.position) > 0.5 and before.distance_to(flying.position) <= 2.01, "弹道必须在快照间隔内外推飞行")
	remote.disable()
	_check(not remote.submit_move(position) and remote.submit_buy("blade") == "连接不可用", "断线后不能继续发命令")
	if failures == 0: print("远程世界测试通过：只读状态、命令确认、快照替换、障碍、冷却、召唤、弹道与表现平滑。")
	quit(1 if failures else 0)

func _check(condition: bool, reason: String) -> void:
	if not condition:
		failures += 1
		push_error(reason)
