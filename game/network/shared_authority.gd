extends "res://network/dev_authority.gd"
## 多个连接共享一局，席位由服务端分配；运行中仅凭本局随机凭据恢复断线席位。

var shared: RefCounted
var slots: Dictionary = {}
var tick := 0
var teams: Array = []
var lobby: RefCounted
var retained: Dictionary = {}
var resumes := preload("res://network/resume_registry.gd").new()
var clock: Callable = Time.get_ticks_msec

func _init(player_count: int = 2) -> void:
	assert(player_count in [2, 4, 10], "开发对局仅支持两席、四席或十席")
	for slot in range(player_count): teams.append(slot % 2)
	lobby = preload("res://network/match_lobby.gd").new(teams)

func connection_capacity() -> int:
	# 留出拒绝额外握手的传输空间，不增加实际游戏席位。
	return teams.size() + 2

func receive(peer_id: int, message: Dictionary) -> Dictionary:
	if message.get("type") == "resume": return _resume(peer_id, message)
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
	if shared != null and shared.players.size() >= teams.size(): return _error("SERVER_FULL")
	var profile: Variant = message.get("profile")
	if not profile is String or not preload("res://simulation/hero_profiles.gd").PROFILES.has(profile): return _error("BAD_PROFILE")
	if shared == null: shared = preload("res://simulation/shared_match.gd").new(teams)
	var slot: int = lobby.claim(peer_id)
	if slot < 0: return _error("SERVER_FULL")
	var world: RefCounted = shared.join(slot, profile)
	var connection := Session.new()
	connection.attach_world(world)
	connection.tick = tick
	sessions[peer_id] = connection
	slots[peer_id] = slot
	retained[slot] = connection
	resumes.issue(slot)
	return _welcome(slot, false)

func _welcome(slot: int, resumed: bool) -> Dictionary:
	var connection: RefCounted = retained[slot]
	var world: RefCounted = connection.world
	return {"type": "welcome", "match": Protocol.MATCH_ID, "entity": world.combat.player.id,
		"resume_token": resumes.token_for(slot), "resumed": resumed,
		"ack": connection.sequence, "event_sequence": connection.event_sequence,
		"team": world.combat.player.team, "slot": slot, "required_players": teams.size(), "tick_rate": Session.TICK_RATE, "mode": "shared"}

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
	var slot: int = slots[peer_id]
	shared.disconnect_player(slot)
	resumes.detach(slot, clock.call())
	slots.erase(peer_id)
	sessions.erase(peer_id)
	if sessions.is_empty():
		for connection in retained.values(): connection.close()
		retained.clear()
		resumes.records.clear()
		shared.dispose()
		shared = null
		tick = 0
		lobby = preload("res://network/match_lobby.gd").new(teams)

func _resume(peer_id: int, message: Dictionary) -> Dictionary:
	if sessions.has(peer_id): return _error("SEAT_OCCUPIED")
	for key in message:
		if key not in ["type", "version", "build", "content", "match", "token"]: return _error("BAD_RESUME")
	for key in Protocol.identity():
		if message.get(key) != Protocol.identity()[key]: return _error("VERSION_MISMATCH")
	if message.get("match") != Protocol.MATCH_ID or shared == null or lobby.phase != "running": return _error("RESUME_UNAVAILABLE")
	var slot: int = resumes.resolve(message.get("token"), clock.call())
	if slot < 0: return _error("INVALID_RESUME")
	# 凭据持有者可以替换尚未被超时清理的旧连接；旧连接立即失去规则操作权。
	for old_peer in slots.keys():
		if slots[old_peer] == slot:
			sessions.erase(old_peer)
			slots.erase(old_peer)
	shared.disconnect_player(slot)
	shared.disconnected.erase(slot)
	var connection: RefCounted = retained[slot]
	connection.pending_events.clear()
	connection.tick = tick
	sessions[peer_id] = connection
	slots[peer_id] = slot
	lobby.seats[slot].peer = peer_id
	lobby.seats[slot].ready = true
	resumes.bind(slot)
	return _welcome(slot, true)
