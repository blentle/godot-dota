extends RefCounted
## 双玩家共享世界；兵线、弹道与战斗每步只推进一次，玩家控制器各自推进订单。

const World = preload("res://simulation/training_world.gd")
var core := preload("res://simulation/combat/combat_system.gd").new()
var navigation := preload("res://simulation/grid_navigation.gd").new()
var match_state: RefCounted
var players: Dictionary = {}
var disconnected: Dictionary = {}
var elapsed := 0.0

func _init() -> void:
	# 占位主英雄不参加未分配的对局；加入时才恢复并注册。
	core.units.erase(core.player.id)
	core.accounts.clear()
	for tree in preload("res://simulation/terrain_layout.gd").trees(): navigation.block(tree.position)
	match_state = preload("res://simulation/lane_match.gd").new(core, navigation)

func join(slot: int, profile: String) -> RefCounted:
	if players.has(slot) or slot not in [0, 1]: return null
	var hero := preload("res://simulation/combat/unit_state.gd").new()
	hero.id = "player" if slot == 0 else "player_2"
	hero.team = slot
	hero.spawn = Vector3(-32, 0, 30) if slot == 0 else Vector3(32, 0, -30)
	if not preload("res://simulation/hero_profiles.gd").apply(hero, profile).is_empty(): return null
	core.register(hero)
	core.accounts[hero.id] = {"gold": 300, "kills": 0, "deaths": 0, "last_hits": 0}
	var perspective := preload("res://simulation/player_combat.gd").new(core, hero)
	var world := World.new(perspective, navigation)
	world.match_state = match_state
	world.target_id = ""
	world.elapsed = elapsed
	players[slot] = world
	return world

func step(delta: float) -> void:
	if match_state.phase == "finished": return
	elapsed += delta
	for world in players.values():
		world.elapsed = elapsed
		world.economy.step(delta)
		world.summons.step(delta)
	core.step(delta)
	match_state.step(delta)
	for slot in players:
		if not disconnected.has(slot): players[slot].step_orders(delta)

func disconnect_player(slot: int) -> void:
	if not players.has(slot): return
	players[slot].submit_stop(true)
	disconnected[slot] = true
	# 开发版本不转交控制权，留场英雄仍可被攻击及复活。

func dispose() -> void:
	for world in players.values(): world.combat.dispose()
	players.clear()
