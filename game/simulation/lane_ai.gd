extends RefCounted
## 兵线行动策略：索敌、接近、攻击和沿路线推进。

const Layout = preload("res://simulation/lane_layout.gd")
var troops: Dictionary = {}

func enroll(unit: RefCounted, lane: int) -> void:
	troops[unit.id] = {"route": Layout.route(unit.team, lane), "waypoint": 1,
		"path": PackedVector3Array(), "refresh": 0.0}

func step(delta: float, combat: RefCounted, routing: RefCounted) -> void:
	for unit in combat.units.values():
		if not unit.alive() or unit.stunned > 0: continue
		if unit.kind == "tower":
			var victim: RefCounted = combat.nearest_enemy(unit, unit.attack_range, true)
			if victim != null: combat.attack(unit, victim)
	for id in troops.keys():
		var unit: RefCounted = combat.units.get(id)
		if unit == null:
			troops.erase(id)
			continue
		if not unit.alive() or unit.stunned > 0 or unit.windup > 0: continue
		var state: Dictionary = troops[id]
		state.refresh -= delta
		var target: RefCounted = combat.nearest_enemy(unit, 8)
		if target != null and unit.position.distance_to(target.position) <= unit.attack_range + target.radius:
			state.path.clear()
			combat.attack(unit, target)
			continue
		if state.refresh <= 0:
			state.refresh = 0.6
			if target != null:
				state.path = routing.find_approach(unit.position, target.position, unit.attack_range + target.radius).slice(1)
			else:
				_plan_route(unit, state, combat, routing)
		_move(unit, state, delta)

func _plan_route(unit: RefCounted, state: Dictionary, combat: RefCounted, routing: RefCounted) -> void:
	var route: PackedVector3Array = state.route
	if state.waypoint < route.size():
		if unit.position.distance_to(route[state.waypoint]) < 1.5: state.waypoint += 1
	if state.waypoint < route.size():
		state.path = routing.find_path(unit.position, route[state.waypoint]).slice(1)
	else:
		var base: RefCounted = combat.units["base_%d" % (1 - unit.team)]
		state.path = routing.find_approach(unit.position, base.position, unit.attack_range + base.radius).slice(1)

func _move(unit: RefCounted, state: Dictionary, delta: float) -> void:
	var remaining := delta * 4.2
	while remaining > 0 and not state.path.is_empty():
		var point: Vector3 = state.path[0]
		var distance: float = unit.position.distance_to(point)
		unit.position = unit.position.move_toward(point, remaining)
		if distance <= remaining: state.path.remove_at(0)
		remaining -= distance
