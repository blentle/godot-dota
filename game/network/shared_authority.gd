extends "res://network/dev_authority.gd"
## 两个连接共享一局，席位由服务端分配；断线席位不允许被新连接接管。

var shared: RefCounted
var slots: Dictionary = {}
var tick := 0
var lobby := preload("res://network/match_lobby.gd").new()

func receive(peer_id: int, message: Dictionary) -> Dictionary:
	if message.get("type") in ["ready", "command"]:
		if not sessions.has(peer_id): return _error("NOT_AUTHORIZED")
		if message.get("type") == "ready":
			if message.size() != 2 or message.get("match") != Protocol.MATCH_ID: return _error("BAD_READY")
			if not lobby.ready(peer_id): return _error("MATCH_ABORTED")
			return lobby.snapshot()
		if lobby.phase != "running": return _error("MATCH_NOT_RUNNING")
	return super.receive(peer_id, message)

func status_packet() -> Dictionary:
	return lobby.snapshot()

func _hello(peer_id: int, message: Dictionary) -> Dictionary:
	for key in Protocol.identity():
		if message.get(key) != Protocol.identity()[key]: return _error("VERSION_MISMATCH")
	if sessions.has(peer_id): return _error("SEAT_OCCUPIED")
	if shared != null and shared.players.size() >= 2: return _error("SERVER_FULL")
	var profile: Variant = message.get("profile")
	if not profile is String or not preload("res://simulation/hero_profiles.gd").PROFILES.has(profile): return _error("BAD_PROFILE")
	if shared == null: shared = preload("res://simulation/shared_match.gd").new()
	var slot: int = lobby.claim(peer_id)
	if slot < 0: return _error("SERVER_FULL")
	var world: RefCounted = shared.join(slot, profile)
	var connection := Session.new()
	connection.attach_world(world)
	connection.tick = tick
	sessions[peer_id] = connection
	slots[peer_id] = slot
	return {"type": "welcome", "match": Protocol.MATCH_ID, "entity": world.combat.player.id,
		"team": slot, "tick_rate": Session.TICK_RATE, "mode": "shared"}

func step() -> void:
	if shared == null: return
	lobby.step(1.0 / Session.TICK_RATE)
	if lobby.phase == "running": shared.step(1.0 / Session.TICK_RATE)
	tick += 1
	for connection in sessions.values(): connection.tick = tick

func snapshot(peer_id: int) -> Dictionary:
	var packet: Dictionary = super.snapshot(peer_id)
	if not packet.is_empty():
		packet["mode"] = "shared"
		packet["connected_players"] = sessions.size()
	return packet

func release_peer(peer_id: int) -> void:
	if not sessions.has(peer_id): return
	lobby.disconnect_peer(peer_id)
	shared.disconnect_player(slots[peer_id])
	slots.erase(peer_id)
	super.release_peer(peer_id)
	if sessions.is_empty():
		shared.dispose()
		shared = null
		tick = 0
		lobby = preload("res://network/match_lobby.gd").new()
