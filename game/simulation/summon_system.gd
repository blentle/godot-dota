extends RefCounted
## 召唤生命周期与跟随策略；到期直接移除，不伪造成可领取奖励的死亡。

const Unit = preload("res://simulation/combat/unit_state.gd")
const DURATION := 15.0
var combat: RefCounted
var routing: RefCounted
var active_id := ""
var remaining := 0.0
var serial := 0
var path := PackedVector3Array()
var refresh := 0.0

func _init(rules: RefCounted, navigation: RefCounted) -> void:
	combat = rules
	routing = navigation

func spawn_point() -> Variant:
	var origin: Vector3 = combat.player.position
	for offset in [Vector3(2, 0, 0), Vector3(-2, 0, 0), Vector3(0, 0, 2), Vector3(0, 0, -2)]:
		var route: PackedVector3Array = routing.find_path(origin, origin + offset)
		if not route.is_empty() and route[-1].distance_to(origin) >= 1:
			return route[-1]
	return null

func create(at: Vector3) -> void:
	serial += 1
	var unit := Unit.new()
	unit.id = "%s_summon_%d" % [combat.player.id, serial]
	unit.owner_id = combat.player.id
	unit.team = combat.player.team
	unit.kind = "summon"
	unit.spawn = at
	unit.max_hp = 180
	unit.max_mana = 0
	unit.damage = 20
	unit.attack_range = 2
	unit.attack_interval = 1.1
	unit.radius = 0.45
	unit.can_respawn = false
	unit.reward = 0
	unit.experience_reward = 0
	unit.reset()
	combat.register(unit)
	active_id = unit.id
	remaining = DURATION
	path.clear()
	refresh = 0

func step(delta: float) -> void:
	if active_id.is_empty(): return
	var unit: RefCounted = combat.units.get(active_id)
	remaining = maxf(0, remaining - delta)
	if unit == null or not unit.alive() or remaining == 0:
		combat.units.erase(active_id)
		active_id = ""
		path.clear()
		return
	if unit.stunned > 0 or unit.windup > 0: return
	var owner: RefCounted = combat.player
	var target: RefCounted = combat.nearest_enemy(unit, 8)
	if owner.alive() and unit.position.distance_to(owner.position) > 12: target = null
	if target != null and unit.position.distance_to(target.position) <= unit.attack_range + target.radius:
		path.clear()
		combat.attack(unit, target)
		return
	refresh -= delta
	if refresh <= 0:
		refresh = 0.4
		if target != null:
			path = routing.find_approach(unit.position, target.position, unit.attack_range + target.radius).slice(1)
		elif owner.alive():
			path = routing.find_approach(unit.position, owner.position, 3).slice(1)
		else:
			path.clear()
	var movement := delta * 6
	while movement > 0 and not path.is_empty():
		var distance: float = unit.position.distance_to(path[0])
		unit.position = unit.position.move_toward(path[0], movement)
		if distance <= movement: path.remove_at(0)
		movement -= distance
