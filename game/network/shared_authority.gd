extends "res://network/dev_authority.gd"
## 两个连接共享一局，席位由服务端分配；断线席位不允许被新连接接管。

var shared: RefCounted
var slots: Dictionary = {}
var tick := 0

func _hello(peer_id: int, message: Dictionary) -> Dictionary:
	for key in Protocol.identity():
		if message.get(key) != Protocol.identity()[key]: return _error("VERSION_MISMATCH")
	if sessions.has(peer_id): return _error("SEAT_OCCUPIED")
	if shared != null and shared.players.size() >= 2: return _error("SERVER_FULL")
	var profile: Variant = message.get("profile")
	if not profile is String or not preload("res://simulation/hero_profiles.gd").PROFILES.has(profile): return _error("BAD_PROFILE")
	if shared == null: shared = preload("res://simulation/shared_match.gd").new()
	var slot: int = shared.players.size()
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
	shared.step(1.0 / Session.TICK_RATE)
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
	shared.disconnect_player(slots[peer_id])
	slots.erase(peer_id)
	super.release_peer(peer_id)
	if sessions.is_empty():
		shared.dispose()
		shared = null
		tick = 0
