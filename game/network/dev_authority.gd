extends RefCounted
## 开发权威端：管理多个席位会话，每个传输连接至多绑定一个独立训练世界。

const Protocol = preload("res://network/dev_protocol.gd")
const Session = preload("res://network/dev_session.gd")
const MAX_SEATS := 4
var sessions: Dictionary = {}

func receive(peer_id: int, message: Dictionary) -> Dictionary:
	if message.get("type") == "hello": return _hello(peer_id, message)
	var session: RefCounted = sessions.get(peer_id)
	if session == null: return _error("NOT_AUTHORIZED")
	if message.get("type") == "ping": return {"type": "pong"}
	if message.get("type") != "command": return _error("BAD_MESSAGE")
	return session.receive_command(message)

func _hello(peer_id: int, message: Dictionary) -> Dictionary:
	var expected := Protocol.identity()
	for key in expected:
		if message.get(key) != expected[key]: return _error("VERSION_MISMATCH")
	if sessions.has(peer_id): return _error("SEAT_OCCUPIED")
	if sessions.size() >= MAX_SEATS: return _error("SERVER_FULL")
	var profile: Variant = message.get("profile")
	if not profile is String: return _error("BAD_PROFILE")
	var session := Session.new()
	if not session.open_world(profile): return _error("BAD_PROFILE")
	sessions[peer_id] = session
	return {"type": "welcome", "match": Protocol.MATCH_ID, "entity": "player", "tick_rate": Session.TICK_RATE}

func step() -> void:
	for session in sessions.values(): session.step()

func session(peer_id: int) -> RefCounted:
	return sessions.get(peer_id)

func snapshot(peer_id: int) -> Dictionary:
	var session: RefCounted = sessions.get(peer_id)
	return {} if session == null else session.snapshot()

func release_peer(peer_id: int) -> void:
	var session: RefCounted = sessions.get(peer_id)
	if session == null: return
	session.close()
	sessions.erase(peer_id)

func _error(code: String) -> Dictionary:
	return {"type": "error", "code": code, "ack": 0}
