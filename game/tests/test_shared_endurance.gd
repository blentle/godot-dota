extends SceneTree
## 十席五分钟规则模拟；加速运行不代替真实网络长局和正式胜负验收。

const Protocol = preload("res://network/dev_protocol.gd")
var failures := 0

func _initialize() -> void:
	var authority := preload("res://network/shared_authority.gd").new(10)
	var hello := Protocol.identity()
	hello.merge({"type": "hello", "profile": "guardian"})
	for slot in range(10):
		authority.receive(100 + slot, hello)
		authority.receive(100 + slot, {"type": "ready", "match": Protocol.MATCH_ID})
		# 保持测试英雄存活，隔离长时资源清理与战斗平衡。
		authority.session(100 + slot).world.combat.player.invulnerable = true
	for frame in range(18000):
		if frame % 1800 == 0:
			for peer in authority.sessions:
				var sequence: int = authority.session(peer).sequence + 1
				authority.receive(peer, {"type": "command", "match": Protocol.MATCH_ID,
					"sequence": sequence, "command": "cast", "target": "summon"})
		authority.step()
		if frame % 3600 == 3599: _check_world(authority)
	_check(absf(authority.shared.elapsed - 300) < 0.001, "十名玩家不得加快或拖慢共享模拟时间")
	_check(authority.shared.match_state.wave >= 10, "五分钟应持续生成兵线")
	for world in authority.shared.players.values():
		_check(world.summons.active_id.is_empty(), "最后一轮召唤物到期必须清理")
		_check(world.combat.gold == 600, "持续收入应只按世界时间发放一次")
	for peer in authority.sessions.keys(): authority.release_peer(peer)
	_check(authority.shared == null and authority.sessions.is_empty(), "长局退出必须释放所有会话")
	if failures == 0: print("十席五分钟规则模拟通过：时钟、收入、波次、快照边界与清理。")
	quit(1 if failures else 0)

func _check_world(authority: RefCounted) -> void:
	var first: Dictionary = authority.snapshot(100)
	_check(first.units.size() <= 138, "单位和尸体数量不得无限增长")
	_check(first.projectiles.size() <= 256, "弹道数量不得无限增长")
	_check(JSON.stringify(first).to_utf8_buffer().size() < 262144, "快照不得超出客户端接收上限")
	for unit in authority.shared.core.units.values():
		_check(unit.position.is_finite() and is_finite(unit.hp), "长时规则状态不得出现非有限值")
	for peer in range(101, 110):
		var packet: Dictionary = authority.snapshot(peer)
		_check(packet.units == first.units and packet.projectiles == first.projectiles and packet.elapsed == first.elapsed, "十席公共状态必须一致")

func _check(value: bool, reason: String) -> void:
	if not value:
		failures += 1
		push_error(reason)
