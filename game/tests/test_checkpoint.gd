extends SceneTree
## 存档往返、继续模拟一致性、原凭据恢复、交易幂等、损坏拒绝和绝对过期。

const State = preload("res://network/checkpoint/authority_state.gd")
const WorldState = preload("res://network/checkpoint/world_state.gd")
const Schema = preload("res://network/checkpoint/checkpoint_schema.gd")
const Protocol = preload("res://network/dev_protocol.gd")
var failures := 0
var now := 1000

func _initialize() -> void:
	var authority := preload("res://network/shared_authority.gd").new()
	authority.clock = func() -> int: return now
	var hello := Protocol.identity()
	hello.merge({"type": "hello", "profile": "ranger"})
	var first: Dictionary = authority.receive(10, hello)
	authority.receive(20, hello)
	for peer in [10, 20]: authority.receive(peer, {"type": "ready", "match": Protocol.MATCH_ID})
	var buy := {"type": "command", "match": Protocol.MATCH_ID, "sequence": 1, "command": "buy", "target": "blade"}
	authority.receive(10, buy)
	_check_lost_ack(State.capture(authority, 100.0), first.resume_token, buy)
	authority.receive(10, {"type": "command", "match": Protocol.MATCH_ID, "sequence": 2, "command": "cast", "target": "summon"})
	authority.receive(10, {"type": "command", "match": Protocol.MATCH_ID, "sequence": 3, "command": "attack", "target": "tower_1_1"})
	for frame in range(180): authority.step()
	# 人为安排一枚在途弹道和死亡单位，覆盖显示快照缺失的规则细节。
	var hero: RefCounted = authority.shared.players[0].combat.player
	authority.shared.core.projectiles.launch(hero, authority.shared.core.units.tower_1_1)
	var victim: RefCounted = authority.shared.players[1].combat.player
	authority.shared.core.apply_damage(hero, victim, 9999)
	var data := State.capture(authority, 100.0)
	_check(Schema.valid(data), "完整权威状态必须符合存档结构")
	var clone: RefCounted = WorldState.restore(data.state.world, authority.teams)
	_check(WorldState.capture(clone) == data.state.world, "往返不能遗漏前摇、路径、弹道、召唤或账本")
	for frame in range(120):
		authority.shared.step(1.0 / 60)
		clone.step(1.0 / 60)
	_check(WorldState.capture(clone) == WorldState.capture(authority.shared), "恢复世界继续模拟必须与原世界一致")
	clone.dispose()
	var restored: RefCounted = State.restore(data, 105.0, func() -> int: return now)
	_check(restored != null and restored.sessions.is_empty(), "重启后必须等待原玩家恢复，不创建假在线连接")
	if restored == null:
		quit(1)
		return
	var request := Protocol.identity()
	request.merge({"type": "resume", "match": Protocol.MATCH_ID, "token": first.resume_token})
	var welcome: Dictionary = restored.receive(30, request)
	_check(welcome.get("resumed", false) and welcome.get("ack") == 3, "原凭据必须恢复原席位和命令序号")
	var gold: int = restored.session(30).world.combat.gold
	var last := {"type": "command", "match": Protocol.MATCH_ID, "sequence": 3, "command": "buy", "target": "vest"}
	restored.receive(30, last)
	_check(restored.session(30).world.combat.gold == gold, "重复序号不得再扣费")
	var expired: RefCounted = State.restore(data, 131.0)
	_check(expired.shared == null, "超出绝对保留期不得因重启复活凭据")
	_check_offline_expiry(data)
	var broken := data.duplicate(true)
	broken.state.world.players[0].economy.slots = ["bad"]
	_check(not Schema.valid(broken), "结构损坏应在创建世界之前拒绝")
	broken = data.duplicate(true)
	broken.identity.build = "old"
	_check(not Schema.valid(broken), "版本不兼容必须拒绝")
	broken = data.duplicate(true)
	broken.state.world.units[0].hp = INF
	_check(not Schema.valid(broken), "非有限数值不能进入恢复世界")
	var service := preload("res://network/checkpoint/checkpoint_service.gd").new()
	service.path = "user://missing-%d/authority.bin" % OS.get_process_id()
	_check(not service.save(authority) and not service.error.is_empty(), "保存失败必须显式返回，不能伪造已持久化")
	_file_roundtrip(data)
	for peer in authority.sessions.keys(): authority.depart_peer(peer)
	for peer in restored.sessions.keys(): restored.depart_peer(peer)
	if restored.shared != null:
		for connection in restored.retained.values(): connection.close()
		restored.shared.dispose()
	if failures == 0: print("权威存档恢复测试通过。")
	quit(1 if failures else 0)

func _check_lost_ack(data: Dictionary, token: String, buy: Dictionary) -> void:
	var restored: RefCounted = State.restore(data, 101.0)
	var request := Protocol.identity()
	request.merge({"type": "resume", "match": Protocol.MATCH_ID, "token": token})
	restored.receive(90, request)
	var gold: int = restored.session(90).world.combat.gold
	var reply: Dictionary = restored.receive(90, buy)
	_check(reply.get("ok", false) and restored.session(90).world.combat.gold == gold, "保存后丢确认，重启重发购买不能再次扣费")
	_check(restored.session(90).world.economy.slots.count("blade") == 1, "重放购买不能复制物品")
	for connection in restored.retained.values(): connection.close()
	restored.shared.dispose()

func _file_roundtrip(data: Dictionary) -> void:
	var storage := preload("res://network/checkpoint/checkpoint_file.gd").new()
	var path := "user://checkpoint-test-%d.bin" % OS.get_process_id()
	_check(storage.write(path, data), "原子保存应成功：" + storage.error)
	_check(storage.read(path) == data, "文件往返必须保持类型和数值")
	var service := preload("res://network/checkpoint/checkpoint_service.gd").new()
	service.path = path
	var fallback := preload("res://network/shared_authority.gd").new(4)
	_check(service.load_authority(fallback) == null and not service.error.is_empty(), "席位不兼容必须阻止启动")
	_check(storage.read(path) == data, "拒绝恢复不得修改原存档")
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	file.seek_end(-1)
	file.store_8(255)
	file.close()
	_check(storage.read(path).is_empty() and not storage.error.is_empty(), "校验失败必须拒绝恢复")
	_check(service.load_authority(fallback) == null and not service.error.is_empty(), "损坏存档不得回退成空白新局")
	DirAccess.remove_absolute(path)

func _check_offline_expiry(data: Dictionary) -> void:
	var paused: RefCounted = State.restore(data, 105.0, func() -> int: return now)
	now += 10000
	var saved := State.capture(paused, 115.0)
	for ticket in saved.state.tickets:
		_check(is_equal_approx(ticket.expires, 130.0), "无人恢复时再次保存不得延长绝对保留期")
	var expired: RefCounted = State.restore(saved, 131.0)
	_check(expired.shared == null, "反复重启不能刷新离线凭据期限")
	for connection in paused.retained.values(): connection.close()
	paused.shared.dispose()

func _check(value: bool, reason: String) -> void:
	if not value:
		failures += 1
		push_error(reason)
