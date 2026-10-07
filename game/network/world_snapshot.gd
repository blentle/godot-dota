extends RefCounted
## 开发全量快照；不作为带战争迷雾的正式对战可见性协议。

const UNIT_FIELDS := ["id", "team", "kind", "role", "profile_id", "hp", "max_hp", "mana", "max_mana",
	"level", "experience", "life_id", "damage", "move_speed", "attack_interval", "attack_range", "radius",
	"windup", "pending_target_id", "skill_cooldown", "area_cooldown", "summon_cooldown", "stunned", "respawn_remaining", "invulnerable"]

static func capture(world: RefCounted, tick: int, acknowledged: int) -> Dictionary:
	var units: Array = []
	for unit in world.combat.units.values():
		var record := {"position": [unit.position.x, unit.position.z]}
		for field in UNIT_FIELDS: record[field] = unit.get(field)
		units.append(record)
	var shots: Array = []
	for id in world.combat.projectiles.active:
		var shot: Dictionary = world.combat.projectiles.active[id]
		shots.append({"id": id, "team": shot.team, "position": [shot.position.x, shot.position.y, shot.position.z]})
	var reasons := {"area": world.skills.reason("area"), "summon": world.skills.reason("summon"),
		"shop": world.economy.availability(world.finished()), "buy": {}}
	for id in preload("res://simulation/item_catalog.gd").ITEMS:
		reasons.buy[id] = world.economy.buy_reason(id, world.finished())
	return {"type": "snapshot", "tick": tick, "ack": acknowledged,
		"gold": world.combat.gold, "inventory": world.economy.slots.duplicate(),
		"units": units, "projectiles": shots, "result": world.result_snapshot(), "reasons": reasons,
		"elapsed": world.elapsed, "order": world.order, "kills": world.combat.kills, "deaths": world.combat.deaths,
		"last_hits": world.combat.last_hits, "wave": world.match_state.wave, "next_wave": world.match_state.next_wave,
		"summon_id": world.summons.active_id, "summon_remaining": world.summons.remaining}
