extends RefCounted
## 开发全量快照；不作为带战争迷雾的正式对战可见性协议。

static func capture(world: RefCounted, tick: int, acknowledged: int) -> Dictionary:
	var units: Array = []
	for unit in world.combat.units.values():
		units.append({"id": unit.id, "team": unit.team, "kind": unit.kind,
			"position": [unit.position.x, unit.position.z], "hp": unit.hp,
			"max_hp": unit.max_hp, "mana": unit.mana, "level": unit.level, "life": unit.life_id})
	return {"type": "snapshot", "tick": tick, "ack": acknowledged,
		"gold": world.combat.gold, "inventory": world.economy.slots.duplicate(),
		"units": units, "result": world.result_snapshot()}
