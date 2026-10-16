extends RefCounted
## 完整规则状态的装配与恢复；保留移动路径、前摇、弹道、召唤和兵线游标。

const Fields = preload("res://network/checkpoint/state_fields.gd")
const Unit = preload("res://simulation/combat/unit_state.gd")

static func capture(shared: RefCounted) -> Dictionary:
	var units: Array = []
	for unit in shared.core.units.values(): units.append(Fields.capture(unit, Fields.UNIT))
	var players: Array = []
	for slot in shared.players:
		var world: RefCounted = shared.players[slot]
		players.append({"slot": slot, "entity": world.combat.player.id,
			"world": Fields.capture(world, Fields.WORLD), "economy": Fields.capture(world.economy, Fields.ECONOMY),
			"summon": Fields.capture(world.summons, Fields.SUMMON)})
	return {"units": units, "players": players, "elapsed": shared.elapsed,
		"accounts": shared.core.accounts.duplicate(true), "ended": shared.core.ended,
		"projectiles": shared.core.projectiles.active.duplicate(true), "next_projectile": shared.core.projectiles.next_id,
		"match": Fields.capture(shared.match_state, Fields.MATCH), "troops": shared.match_state.ai.troops.duplicate(true)}

static func restore(data: Dictionary, teams: Array) -> RefCounted:
	var shared := preload("res://simulation/shared_match.gd").new(teams)
	shared.core.units.clear()
	shared.core.accounts = data.accounts.duplicate(true)
	for record in data.units:
		var unit := Unit.new()
		Fields.apply(unit, Fields.UNIT, record)
		shared.core.units[unit.id] = unit
	shared.core.ended = data.ended
	shared.core.projectiles.active = data.projectiles.duplicate(true)
	shared.core.projectiles.next_id = data.next_projectile
	shared.elapsed = data.elapsed
	Fields.apply(shared.match_state, Fields.MATCH, data.match)
	shared.match_state.ai.troops = data.troops.duplicate(true)
	for record in data.players:
		var perspective := preload("res://simulation/player_combat.gd").new(shared.core, shared.core.units[record.entity])
		var world := preload("res://simulation/training_world.gd").new(perspective, shared.navigation)
		world.shared_rewards = true
		world.match_state = shared.match_state
		Fields.apply(world, Fields.WORLD, record.world)
		Fields.apply(world.economy, Fields.ECONOMY, record.economy)
		Fields.apply(world.summons, Fields.SUMMON, record.summon)
		shared.players[record.slot] = world
	return shared
