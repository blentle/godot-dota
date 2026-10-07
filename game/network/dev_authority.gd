extends RefCounted
## 单席位开发权威端：连接绑定控制权，严格序号保证命令至多执行一次。

const Protocol = preload("res://network/dev_protocol.gd")
const Snapshot = preload("res://network/world_snapshot.gd")
var world: RefCounted
var owner := 0
var sequence := 0
var tick := 0
var last_reply: Dictionary = {}

func receive(peer_id: int, message: Dictionary) -> Dictionary:
	if message.get("type") == "hello": return _hello(peer_id, message)
	if peer_id != owner or owner == 0: return _error("NOT_AUTHORIZED")
	if message.get("type") != "command": return _error("BAD_MESSAGE")
	var rejection := Protocol.command_error(message)
	if not rejection.is_empty(): return _error(rejection)
	var requested := int(message.sequence)
	if requested == sequence: return last_reply.duplicate(true)
	if requested != sequence + 1: return _error("SEQUENCE_MISMATCH")
	sequence = requested
	var reason := _execute(message)
	last_reply = {"type": "ack", "sequence": sequence, "ok": reason.is_empty(), "reason": reason}
	return last_reply.duplicate(true)

func _hello(peer_id: int, message: Dictionary) -> Dictionary:
	var expected := Protocol.identity()
	for key in expected:
		if message.get(key) != expected[key]: return _error("VERSION_MISMATCH")
	if owner != 0: return _error("SEAT_OCCUPIED")
	var candidate := preload("res://simulation/training_world.gd").new()
	var profile: Variant = message.get("profile")
	if not profile is String: return _error("BAD_PROFILE")
	if not candidate.configure_hero(profile).is_empty(): return _error("BAD_PROFILE")
	candidate.start_match()
	world = candidate
	owner = peer_id
	sequence = 0
	tick = 0
	last_reply = {}
	return {"type": "welcome", "match": Protocol.MATCH_ID, "entity": "player", "tick_rate": 60}

func release_peer(peer_id: int) -> void:
	if owner != peer_id: return
	owner = 0
	world = null
	sequence = 0
	tick = 0
	last_reply = {}

func step() -> void:
	if world == null: return
	world.step(1.0 / 60.0)
	tick += 1

func snapshot() -> Dictionary:
	return {} if world == null else Snapshot.capture(world, tick, sequence)

func _execute(message: Dictionary) -> String:
	if world.finished(): return "对局已经结束"
	var target: Variant = message.get("target")
	match message.command:
		"move": return "" if world.submit_move(Vector3(target[0], 0, target[1])) else "无法移动"
		"attack": return world.submit_attack(target)
		"buy": return world.submit_buy(target)
		"sell": return world.submit_sell(int(target))
		"cast": return world.submit_strike() if target == "strike" else world.submit_skill(target)
		"stop", "hold": world.submit_stop(message.command == "hold")
	return ""

func _error(code: String) -> Dictionary:
	return {"type": "error", "code": code, "ack": sequence if owner != 0 else 0}
