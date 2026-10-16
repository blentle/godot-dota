extends RefCounted
## 席位与权威世界的存档协调器；恢复时先冻结全部席位，再由原凭据重新绑定。

const Fields = preload("res://network/checkpoint/state_fields.gd")
const WorldState = preload("res://network/checkpoint/world_state.gd")
const Protocol = preload("res://network/dev_protocol.gd")

static func capture(authority: RefCounted, unix_now: float) -> Dictionary:
	var data := {"schema": 1, "identity": Protocol.identity(), "state": {}}
	if authority.shared == null or authority.lobby.phase != "running": return data
	var tickets: Array = []
	for slot in authority.resumes.records:
		var record: Dictionary = authority.resumes.records[slot]
		var remaining: int = 30000 if record.deadline == 0 else maxi(0, record.deadline - int(authority.clock.call()))
		tickets.append({"slot": slot, "token": record.token, "expires": unix_now + remaining / 1000.0})
	var sessions: Array = []
	for slot in authority.retained:
		sessions.append({"slot": slot, "fields": Fields.capture(authority.retained[slot], Fields.SESSION)})
	data.state = {"teams": authority.teams.duplicate(), "tick": authority.tick,
		"world": WorldState.capture(authority.shared), "sessions": sessions, "tickets": tickets}
	return data

static func restore(data: Dictionary, unix_now: float, clock: Callable = Time.get_ticks_msec) -> RefCounted:
	if not preload("res://network/checkpoint/checkpoint_schema.gd").valid(data): return null
	if data.state.is_empty(): return null
	var state: Dictionary = data.state
	var authority := preload("res://network/shared_authority.gd").new(state.teams.size())
	authority.clock = clock
	for ticket in state.tickets:
		var remaining: int = mini(30000, int((ticket.expires - unix_now) * 1000))
		if remaining > 0:
			authority.resumes.records[ticket.slot] = {"token": ticket.token, "deadline": int(clock.call()) + remaining}
	if authority.resumes.records.is_empty(): return authority
	authority.shared = WorldState.restore(state.world, state.teams)
	authority.tick = state.tick
	authority.lobby.phase = "running"
	for record in state.sessions:
		var connection := preload("res://network/dev_session.gd").new()
		connection.attach_world(authority.shared.players[record.slot])
		Fields.apply(connection, Fields.SESSION, record.fields)
		authority.retained[record.slot] = connection
		authority.shared.disconnect_player(record.slot)
		authority.lobby.seats[record.slot].peer = -1
	return authority
