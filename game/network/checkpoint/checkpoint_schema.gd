extends RefCounted
## 恢复前的结构与引用校验；校验失败不能触及当前权威世界。

const Fields = preload("res://network/checkpoint/state_fields.gd")
const Protocol = preload("res://network/dev_protocol.gd")

static func valid(data: Dictionary) -> bool:
	if not shape(data, {"schema": 1, "identity": {}, "state": {}}): return false
	if data.schema != 1 or data.identity != Protocol.identity(): return false
	if data.state.is_empty(): return true
	var state: Dictionary = data.state
	if not shape(state, {"teams": [], "tick": 0, "world": {}, "sessions": [], "tickets": []}): return false
	if state.teams.size() not in [2, 4, 10] or state.tick < 0: return false
	for slot in range(state.teams.size()):
		if state.teams[slot] != slot % 2: return false
	if not _world(state.world, state.teams): return false
	if state.sessions.size() != state.teams.size() or state.tickets.size() > state.teams.size(): return false
	var session := preload("res://network/dev_session.gd").new()
	var seen := {}
	for record in state.sessions:
		if not shape(record, {"slot": 0, "fields": {}}) or not _slot(record.slot, state.teams, seen): return false
		if not Fields.matches(session, Fields.SESSION, record.fields): return false
		if record.fields.sequence < 0 or record.fields.tick < 0 or record.fields.event_sequence < 0: return false
		var reply: Dictionary = record.fields.last_reply
		if record.fields.sequence == 0 and not reply.is_empty(): return false
		if record.fields.sequence > 0:
			if not shape(reply, {"type": "", "sequence": 0, "ok": true, "reason": ""}): return false
			if reply.type != "ack" or reply.sequence != record.fields.sequence: return false
	seen.clear()
	var tokens := {}
	for ticket in state.tickets:
		if not shape(ticket, {"slot": 0, "token": "", "expires": 0.0}) or not _slot(ticket.slot, state.teams, seen): return false
		if ticket.token.length() != 64 or not ticket.token.is_valid_hex_number() or tokens.has(ticket.token): return false
		if not is_finite(ticket.expires): return false
		tokens[ticket.token] = true
	return true

static func _world(world: Dictionary, teams: Array) -> bool:
	if not shape(world, {"units": [], "players": [], "elapsed": 0.0, "accounts": {}, "ended": true,
		"projectiles": {}, "next_projectile": 0, "match": {}, "troops": {}}): return false
	if world.elapsed < 0 or world.units.size() > 512 or world.players.size() != teams.size(): return false
	if not shape(world.match, {"phase": "", "winner": 0, "wave": 0, "next_wave": 0.0}): return false
	if world.match.phase not in ["running", "finished"] or world.match.winner not in [-1, 0, 1]: return false
	if world.ended != (world.match.phase == "finished"): return false
	if (world.match.winner == -1) == world.ended: return false
	var units := {}
	var sample := preload("res://simulation/combat/unit_state.gd").new()
	for record in world.units:
		if not Fields.matches(sample, Fields.UNIT, record): return false
		if record.id.is_empty() or units.has(record.id) or record.team not in [0, 1]: return false
		if record.hp < 0 or record.max_hp <= 0 or record.hp > record.max_hp or record.life_id < 0: return false
		if record.mana < 0 or record.mana > record.max_mana: return false
		if record.kind not in ["hero", "creep", "tower", "base", "summon"]: return false
		units[record.id] = record
	for team in range(2):
		if not units.has("base_%d" % team) or units["base_%d" % team].kind != "base": return false
		for lane in range(3):
			if not units.has("tower_%d_%d" % [team, lane]) or units["tower_%d_%d" % [team, lane]].kind != "tower": return false
	var prototype := preload("res://simulation/training_world.gd").new()
	var seen := {}
	for player in world.players:
		if not shape(player, {"slot": 0, "entity": "", "world": {}, "economy": {}, "summon": {}}): return false
		if not _slot(player.slot, teams, seen): return false
		var id := "player" if player.slot == 0 else "player_%d" % (player.slot + 1)
		if player.entity != id or not units.has(id) or units[id].team != teams[player.slot]: return false
		if not preload("res://simulation/hero_profiles.gd").PROFILES.has(units[id].profile_id): return false
		if not world.accounts.has(id) or not shape(world.accounts[id], {"gold": 0, "kills": 0, "deaths": 0, "last_hits": 0}): return false
		for amount in world.accounts[id].values():
			if amount < 0: return false
		if not Fields.matches(prototype, Fields.WORLD, player.world): return false
		if player.world.elapsed != world.elapsed: return false
		if not player.world._result.is_empty() and not _result(player.world._result): return false
		if not Fields.matches(prototype.economy, Fields.ECONOMY, player.economy): return false
		if not Fields.matches(prototype.summons, Fields.SUMMON, player.summon): return false
		if player.economy.slots.size() != 6 or not shape(player.economy.bonus, {"damage": 0.0, "hp": 0.0, "mana": 0.0, "speed": 0.0}): return false
		for item in player.economy.slots:
			if not item is String or (item != "" and not preload("res://simulation/item_catalog.gd").ITEMS.has(item)): return false
		if player.summon.active_id != "" and not units.has(player.summon.active_id): return false
	if world.accounts.size() != teams.size() or world.projectiles.size() > 1024 or world.next_projectile < 1: return false
	for id in world.projectiles:
		var shot: Variant = world.projectiles[id]
		if not id is int or not shape(shot, {"id": 0, "actor": "", "team": 0, "target": "", "life": 0,
			"damage": 0.0, "speed": 0.0, "remaining": 0.0, "position": Vector3.ZERO}): return false
		if shot.id != id or id < 1 or id >= world.next_projectile: return false
		if shot.team not in [0, 1] or shot.speed < 0 or shot.damage < 0 or shot.remaining <= 0: return false
	for id in world.troops:
		if not units.has(id) or units[id].kind != "creep": return false
		if not shape(world.troops[id], {"route": PackedVector3Array(), "waypoint": 0, "path": PackedVector3Array(), "refresh": 0.0}): return false
		if world.troops[id].waypoint < 0 or world.troops[id].waypoint > world.troops[id].route.size(): return false
	return Fields.values_safe(world)

static func _result(data: Dictionary) -> bool:
	if not shape(data, {"winner": 0, "seconds": 0, "profile": "", "level": 0, "gold": 0,
		"kills": 0, "deaths": 0, "last_hits": 0, "wave": 0, "inventory": []}): return false
	if data.winner not in [0, 1] or data.inventory.size() != 6: return false
	if not preload("res://simulation/hero_profiles.gd").PROFILES.has(data.profile): return false
	for item in data.inventory:
		if not item is String or (item != "" and not preload("res://simulation/item_catalog.gd").ITEMS.has(item)): return false
	return true

static func shape(data: Variant, template: Dictionary) -> bool:
	if not data is Dictionary or data.size() != template.size(): return false
	for key in template:
		if not data.has(key) or typeof(data[key]) != typeof(template[key]): return false
	return true

static func _slot(slot: int, teams: Array, seen: Dictionary) -> bool:
	if slot < 0 or slot >= teams.size() or seen.has(slot): return false
	seen[slot] = true
	return true
