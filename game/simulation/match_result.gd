extends RefCounted
## 值类型结算快照，不保留可变单位、库存或视图的引用。

static func capture(world: RefCounted) -> Dictionary:
	return {"winner": world.match_state.winner, "seconds": floori(world.elapsed),
		"profile": world.combat.player.profile_id, "level": world.combat.player.level,
		"gold": world.combat.gold, "kills": world.combat.kills,
		"deaths": world.combat.deaths, "last_hits": world.combat.last_hits,
		"wave": world.match_state.wave, "inventory": world.economy.slots.duplicate()}
