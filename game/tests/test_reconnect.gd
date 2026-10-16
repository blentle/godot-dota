extends SceneTree
## 凭据恢复、旧连接撤权、交易幂等、期限与跨局隔离。

const Protocol = preload("res://network/dev_protocol.gd")
var failures := 0
var now := 1000

func _initialize() -> void:
	var authority := preload("res://network/shared_authority.gd").new()
	authority.clock = func() -> int: return now
	var hello := Protocol.identity()
	hello.merge({"type": "hello", "profile": "guardian"})
	var welcome: Dictionary = authority.receive(10, hello)
	authority.receive(20, hello)
	var token: String = welcome.resume_token
	_check(token.length() == 64, "恢复凭据必须随机生成且不为空")
	_check(authority.receive(30, _resume(token)).code == "RESUME_UNAVAILABLE", "装载阶段不支持恢复")
	for peer in [10, 20]: authority.receive(peer, {"type": "ready", "match": Protocol.MATCH_ID})
	var buy := {"type": "command", "match": Protocol.MATCH_ID, "sequence": 1, "command": "buy", "target": "blade"}
	_check(authority.receive(10, buy).ok, "初始交易应成功")
	var world: RefCounted = authority.session(10).world
	_check(authority.receive(30, _resume("0".repeat(64))).code == "INVALID_RESUME", "未知凭据不能接管席位")
	var forged := _resume(token)
	forged.slot = 1
	_check(authority.receive(30, forged).code == "BAD_RESUME", "不能指定他人席位")
	var resumed: Dictionary = authority.receive(30, _resume(token))
	_check(resumed.resumed and resumed.entity == welcome.entity and resumed.ack == 1, "新连接应恢复原英雄与已执行序号")
	_check(authority.session(30).world == world and not authority.sessions.has(10), "不能复制世界或同时保留两份控制权")
	_check(authority.receive(10, buy).code == "NOT_AUTHORIZED", "旧连接必须立即失去权限")
	authority.release_peer(10)
	_check(authority.session(30) != null, "旧传输迟到的断开事件不能释放新连接")
	_check(authority.receive(30, buy).ok and world.economy.slots.count("blade") == 1 and world.combat.gold == 200, "已成交但丢失确认的交易不能重复扣费")
	authority.release_peer(30)
	for frame in range(60): authority.step()
	_check(authority.shared.disconnected.has(0) and world.combat.gold == 201, "断线英雄保留且世界继续推进")
	now += 29999
	_check(authority.receive(40, _resume(token)).get("resumed", false), "保留期内应恢复")
	_check(not authority.shared.disconnected.has(0) and authority.lobby.seats[0].peer == 40, "恢复后席位和控制器均应重新绑定")
	authority.release_peer(40)
	now += 30000
	_check(authority.receive(50, _resume(token)).code == "INVALID_RESUME", "到期边界不得恢复")
	authority.depart_peer(20)
	_check(authority.shared == null and authority.retained.is_empty(), "全员离开应清除保留会话")
	authority.receive(60, hello)
	authority.receive(70, hello)
	for peer in [60, 70]: authority.receive(peer, {"type": "ready", "match": Protocol.MATCH_ID})
	_check(authority.receive(80, _resume(token)).code == "INVALID_RESUME", "旧局凭据不能进入新局")
	for peer in [60, 70]: authority.depart_peer(peer)
	if failures == 0: print("重连权威规则通过。")
	quit(1 if failures else 0)

func _resume(token: String) -> Dictionary:
	var request := Protocol.identity()
	request.merge({"type": "resume", "match": Protocol.MATCH_ID, "token": token})
	return request

func _check(value: bool, reason: String) -> void:
	if not value:
		failures += 1
		push_error(reason)
