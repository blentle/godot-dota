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
	var packet: Dictionary = JSON.parse_string(JSON.stringify(authority.snapshot()))
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
	remote.apply(JSON.parse_string(JSON.stringify(authority.snapshot())))
	_check(remote.combat.gold == 200 and remote.economy.slots[0] == "blade", "服务端库存必须覆盖本地显示")
	_check(remote.combat.player.damage == 67 and remote.combat.player.summon_cooldown > 0, "派生属性和冷却必须同步")
	_check(remote.combat.units.has(remote.summons.active_id), "召唤物必须包含在快照中")
	_check(remote.pending.is_empty(), "确认应释放命令队列")
	remote.apply(packet)
	_check(remote.combat.gold == 200, "旧快照不能回退状态")
	var tree: Dictionary = preload("res://simulation/terrain_layout.gd").trees()[0]
	_check(not authority.world.submit_move(tree.position), "无界面服务器必须拒绝走进树木障碍")
	var player: RefCounted = authority.world.combat.player
	var target: RefCounted = authority.world.combat.units.tower_1_0
	authority.world.combat.projectiles.launch(player, target)
	authority.step()
	remote.apply(JSON.parse_string(JSON.stringify(authority.snapshot())))
	_check(remote.combat.projectiles.active.size() == 1, "在途弹道必须同步给视图")
	remote.disable()
	_check(not remote.submit_move(position) and remote.submit_buy("blade") == "连接不可用", "断线后不能继续发命令")
	if failures == 0: print("远程世界测试通过：只读状态、命令确认、快照替换、障碍、冷却、召唤与弹道。")
	quit(1 if failures else 0)

func _check(condition: bool, reason: String) -> void:
	if not condition:
		failures += 1
		push_error(reason)
