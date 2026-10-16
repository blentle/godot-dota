extends SceneTree
## 十席完整规则长局：两种获胜阵营均经正常命令推塔到结算，并检查终局冻结。

const Protocol = preload("res://network/dev_protocol.gd")
const Orders = preload("res://tests/full_match_orders.gd")
var failures := 0

func _initialize() -> void:
	for team in range(2): _play(team)
	quit(1 if failures else 0)

func _play(team: int) -> void:
	var authority := preload("res://network/shared_authority.gd").new(10)
	var hello := Protocol.identity()
	hello.merge({"type": "hello", "profile": "guardian"})
	for peer in range(100, 110):
		authority.receive(peer, hello)
		authority.receive(peer, {"type": "ready", "match": Protocol.MATCH_ID})
	for frame in range(36000):
		if frame % 60 == 0:
			for peer in authority.sessions:
				var intent: Dictionary = Orders.next(authority.session(peer).world, team)
				if not intent.is_empty(): _command(authority, peer, intent)
		authority.step()
		if authority.shared.match_state.phase == "finished": break
	_check(authority.shared.match_state.winner == team, "正常命令必须在十分钟内完成预期阵营胜利")
	_check(authority.shared.elapsed >= 300, "完整长局必须至少覆盖五分钟兵线")
	var results: Array = []
	for peer in range(100, 110):
		var world: RefCounted = authority.session(peer).world
		results.append(world.result_snapshot())
		_check(world.finished(), "所有玩家必须取得结算")
		_check(results.back().get("winner", -1) == team, "所有结算胜方必须相同")
		var reply: Dictionary = _command(authority, peer, {"command": "buy", "target": "blade"})
		_check(not reply.get("ok", true) and reply.get("reason") == "对局已经结束", "终局命令必须拒绝")
	var before: Dictionary = authority.snapshot(100)
	for frame in range(600): authority.step()
	var after: Dictionary = authority.snapshot(100)
	for key in ["units", "elapsed", "projectiles", "gold", "wave", "result"]:
		_check(before[key] == after[key], "结束后规则必须冻结：" + key)
	for index in range(10):
		_check(results[index] == authority.session(100 + index).world.result_snapshot(), "个人结算不得漂移")
	for peer in authority.sessions.keys(): authority.depart_peer(peer)
	_check(authority.shared == null, "全员退出后应可开启下一局")
	print("FULL_MATCH_RULE winner=%d elapsed=%.2f" % [team, before.elapsed])

func _command(authority: RefCounted, peer: int, intent: Dictionary) -> Dictionary:
	var request := intent.duplicate()
	request.merge({"type": "command", "match": Protocol.MATCH_ID, "sequence": authority.session(peer).sequence + 1})
	return authority.receive(peer, request)

func _check(value: bool, reason: String) -> void:
	if not value:
		failures += 1
		push_error(reason)
