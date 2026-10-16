extends SceneTree
## 全员意外断线保留、空场暂停、到期清理与主动离场撤权。

const Protocol = preload("res://network/dev_protocol.gd")
var now := 1000
var failures := 0

func _initialize() -> void:
	var authority := preload("res://network/shared_authority.gd").new()
	authority.clock = func() -> int: return now
	var hello := Protocol.identity()
	hello.merge({"type": "hello", "profile": "guardian"})
	var first: Dictionary = authority.receive(10, hello)
	var second: Dictionary = authority.receive(20, hello)
	for peer in [10, 20]: authority.receive(peer, {"type": "ready", "match": Protocol.MATCH_ID})
	authority.step()
	var world: RefCounted = authority.shared
	var elapsed: float = world.elapsed
	for peer in [10, 20]: authority.release_peer(peer)
	for frame in range(120): authority.step()
	_check(authority.shared == world and world.elapsed == elapsed, "全员断线必须保留世界并暂停游戏时间")
	_check(authority.receive(30, hello).code == "SERVER_FULL", "保留局不能被新玩家占用")
	now += 12000
	_check(authority.receive(30, _resume(first.resume_token)).get("resumed", false), "全员断开后首人应能恢复")
	authority.step()
	_check(world.elapsed > elapsed, "首人恢复后应继续模拟")
	_check(authority.receive(40, _resume(second.resume_token)).get("resumed", false), "第二人也应恢复原席位")
	var leave := {"type": "leave", "match": Protocol.MATCH_ID}
	_check(authority.receive(30, {"type": "leave", "match": "wrong"}).code == "BAD_LEAVE", "错误对局不能撤销席位")
	_check(authority.receive(30, leave).type == "left", "主动离场必须确认")
	_check(authority.receive(50, _resume(first.resume_token)).code == "INVALID_RESUME", "主动离场后凭据必须失效")
	authority.receive(40, leave)
	_check(authority.shared == null and authority.retained.is_empty(), "全员主动离场必须立即清理")
	for peer in [60, 70]:
		authority.receive(peer, hello)
		authority.receive(peer, {"type": "ready", "match": Protocol.MATCH_ID})
	for peer in [60, 70]: authority.release_peer(peer)
	now += 29999
	authority.step()
	_check(authority.shared != null, "保留期结束前不能清理")
	now += 1
	authority.step()
	_check(authority.shared == null and authority.resumes.records.is_empty(), "到期必须清理空场及所有凭据")
	_check(authority.receive(80, hello).entity == "player", "清理后应可创建新局")
	authority.depart_peer(80)
	if failures == 0: print("全员断网保留与主动离场测试通过。")
	quit(1 if failures else 0)

func _resume(token: String) -> Dictionary:
	var request := Protocol.identity()
	request.merge({"type": "resume", "match": Protocol.MATCH_ID, "token": token})
	return request

func _check(value: bool, reason: String) -> void:
	if not value:
		failures += 1
		push_error(reason)
