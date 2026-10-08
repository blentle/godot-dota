extends SceneTree
## 验证装载屏障、副作用边界、重复就绪、超时与干净新局。

const Protocol = preload("res://network/dev_protocol.gd")
var failures := 0

func _initialize() -> void:
	var authority := preload("res://network/shared_authority.gd").new()
	var hello := Protocol.identity()
	hello.merge({"type": "hello", "profile": "guardian"})
	var ready := {"type": "ready", "match": Protocol.MATCH_ID}
	_check(authority.receive(99, ready).code == "NOT_AUTHORIZED", "未握手不能就绪")
	authority.receive(10, hello)
	var world: RefCounted = authority.session(10).world
	var before: Array = authority.snapshot(10).units
	for frame in range(120): authority.step()
	_check(world.elapsed == 0 and world.combat.gold == 300, "不足人数时不能推进时间与收入")
	_check(authority.snapshot(10).units == before, "等待期间所有单位必须冻结")
	var command := {"type": "command", "match": Protocol.MATCH_ID, "sequence": 1, "command": "buy", "target": "blade"}
	_check(authority.receive(10, command).code == "MATCH_NOT_RUNNING", "开局前必须拒绝交易")
	_check(authority.session(10).sequence == 0 and world.combat.gold == 300, "拒绝不能消费序号或金币")
	_check(authority.receive(10, {"type": "ready", "match": "wrong"}).code == "BAD_READY", "错误对局就绪必须拒绝")
	authority.receive(10, ready)
	authority.receive(10, ready)
	_check(authority.lobby.ready_count() == 1 and authority.lobby.phase == "waiting", "重复就绪不能代替第二位玩家")
	authority.receive(20, hello)
	for frame in range(60): authority.step()
	_check(world.elapsed == 0 and authority.lobby.phase == "loading", "满员但未全员就绪仍应冻结")
	authority.receive(20, ready)
	authority.step()
	_check(authority.lobby.phase == "running" and absf(world.elapsed - 1.0 / 60) < 0.00001, "全员就绪后才能统一推进一步")
	_check(authority.receive(10, command).ok and world.combat.gold == 200, "开局后首个交易应正常执行")
	authority.release_peer(10)
	_check(authority.lobby.phase == "running", "开局后断线不能取消其他玩家对局")
	authority.release_peer(20)
	authority.receive(30, hello)
	authority.receive(40, hello)
	for frame in range(1801): authority.step()
	_check(authority.lobby.phase == "aborted" and authority.shared.elapsed == 0, "装载超时必须取消且不推进世界")
	_check(authority.receive(30, ready).code == "MATCH_ABORTED", "迟到就绪不能复活已取消对局")
	authority.release_peer(30)
	authority.release_peer(40)
	authority.receive(50, hello)
	authority.receive(60, hello)
	authority.release_peer(50)
	_check(authority.lobby.phase == "aborted", "开局前断线必须取消装载")
	authority.release_peer(60)
	authority.receive(70, hello)
	_check(authority.lobby.phase == "waiting" and authority.lobby.ready_count() == 0 and authority.shared.elapsed == 0, "新局不得继承就绪与时间")
	authority.release_peer(70)
	var table := preload("res://network/match_lobby.gd").new([0, 0, 1, 1])
	for peer in range(1, 5):
		_check(table.claim(peer) == peer - 1, "席位表应按配置分配")
		table.ready(peer)
	_check(table.phase == "running" and table.snapshot().seats.size() == 4, "席位管理不应硬编码两人；不代表四人战斗已实现")
	if failures == 0: print("装载屏障测试通过。")
	quit(1 if failures else 0)

func _check(value: bool, reason: String) -> void:
	if not value:
		failures += 1
		push_error(reason)
