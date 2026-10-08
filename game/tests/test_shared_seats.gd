extends SceneTree
## 四席权威路由：人数屏障、阵营、出生点、独立命令序号与新局席位配置。

const Protocol = preload("res://network/dev_protocol.gd")
var failures := 0

func _initialize() -> void:
	var authority := preload("res://network/shared_authority.gd").new(4)
	var hello := Protocol.identity()
	hello.merge({"type": "hello", "profile": "guardian"})
	var ready := {"type": "ready", "match": Protocol.MATCH_ID}
	var spawns: Array = []
	for slot in range(4):
		var peer := 100 + slot
		var welcome: Dictionary = authority.receive(peer, hello)
		_check(welcome.slot == slot and welcome.team == slot % 2 and welcome.required_players == 4, "欢迎包必须区分席位与阵营")
		var world: RefCounted = authority.session(peer).world
		_check(not spawns.has(world.position), "英雄出生点不得重叠")
		spawns.append(world.position)
		_check(not world.routing.find_path(world.position, world.position + Vector3(1, 0, 0)).is_empty(), "出生点必须能通向战场")
		authority.receive(peer, ready)
		if slot < 3:
			for frame in range(60): authority.step()
			_check(authority.shared.elapsed == 0 and authority.lobby.phase == "waiting", "不足四人不能提前开局")
	_check(authority.lobby.phase == "running", "四席就绪必须开局")
	_check(authority.receive(200, hello).code == "SERVER_FULL", "第五个游戏席位必须拒绝")
	for slot in range(4):
		var peer := 100 + slot
		var reply: Dictionary = authority.receive(peer, _command("buy", "blade"))
		_check(reply.ok, "每个出生点均应允许基地购物")
		authority.receive(peer, _command("buy", "blade"))
		var packet: Dictionary = authority.snapshot(peer)
		_check(packet.inventory.count("blade") == 1 and packet.gold == 200 and packet.ack == 1, "各席重复购买只能扣费一次")
	var forged := _command("move", [0, 0])
	forged.sequence = 2
	forged.slot = 3
	_check(authority.receive(100, forged).code == "UNEXPECTED_FIELD", "不能伪造其他席位执行命令")
	var before: Vector3 = authority.session(100).world.position
	var move := _command("move", [-30, 32])
	move.sequence = 2
	_check(authority.receive(102, move).ok, "第三席应能操作自己的英雄")
	for frame in range(30): authority.step()
	_check(authority.session(100).world.position == before, "同队第三席不能移动第一席英雄")
	_check(authority.session(102).world.position != spawns[2], "第三席自身应移动")
	authority.release_peer(102)
	_check(authority.lobby.phase == "running" and authority.sessions.size() == 3, "断线不能停止其他三人")
	_check(authority.receive(201, hello).code == "SERVER_FULL", "开局后不能接管断线席位")
	for peer in [100, 101, 103]: authority.release_peer(peer)
	authority.receive(300, hello)
	_check(authority.lobby.seats.size() == 4 and authority.lobby.phase == "waiting", "新局必须保留四席配置并清空就绪")
	authority.release_peer(300)
	if failures == 0: print("四席权威规则通过。")
	quit(1 if failures else 0)

func _command(kind: String, target: Variant) -> Dictionary:
	return {"type": "command", "match": Protocol.MATCH_ID, "sequence": 1, "command": kind, "target": target}

func _check(value: bool, reason: String) -> void:
	if not value:
		failures += 1
		push_error(reason)
