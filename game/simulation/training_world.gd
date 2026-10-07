extends RefCounted
## 离线世界协调器：命令入口负责导航与战斗组合，表现层只读状态。

const Navigation = preload("res://simulation/grid_navigation.gd")
const Combat = preload("res://simulation/combat/combat_system.gd")
var routing := Navigation.new()
var combat := Combat.new()
var economy := preload("res://simulation/economy_system.gd").new(combat)
var path := PackedVector3Array()
var order := "待命"
var elapsed := 0.0
var attacking := false
var target_id := "enemy"
var match_state: RefCounted
var chase_refresh := 0.0
var position: Vector3:
	get: return combat.player.position
	set(value): combat.player.position = value
var obstacles: Array[Vector3]:
	get: return routing.obstacles

func _init() -> void:
	combat.combat_event.connect(_on_combat_event)

func block(at: Vector3, radius: int = 1) -> void:
	routing.block(at, radius)

func submit_move(target: Vector3) -> bool:
	if finished() or not combat.player.alive() or combat.player.stunned > 0: return false
	if not _plan_path(target): return false
	attacking = false
	combat.cancel_attack(combat.player)
	order = "移动中" if not path.is_empty() else "待命"
	return true

func submit_attack(id: String = "") -> String:
	if not id.is_empty(): target_id = id
	if finished(): return "对局已经结束"
	if not combat.player.alive(): return "单位已倒下，等待复活"
	if combat.player.stunned > 0: return "单位被眩晕"
	var target := current_target()
	if target == null or not target.alive(): return "目标已倒下"
	var reason: String = combat.chain.check_target({"actor": combat.player, "target": target})
	if not reason.is_empty(): return reason
	target_id = target.id
	var approach := routing.find_approach(position, target.position, combat.player.attack_range + target.radius)
	if approach.is_empty(): return "无法到达目标"
	path = approach.slice(1)
	attacking = true
	order = "追击目标"
	return ""

func submit_strike() -> String:
	if finished(): return "对局已经结束"
	return combat.cast_strike(current_target())

func submit_stop(hold: bool = false) -> void:
	path.clear()
	attacking = false
	combat.cancel_attack(combat.player)
	if combat.player.alive(): order = "保持位置" if hold else "停止"

func _plan_path(target: Vector3) -> bool:
	var result := routing.find_path(position, target)
	if result.is_empty(): return false
	path = result.slice(1)
	return true

func step(delta: float) -> void:
	if finished(): return
	elapsed += delta
	if match_state != null: economy.step(delta)
	combat.step(delta)
	if match_state != null: match_state.step(delta)
	if finished():
		submit_stop()
		order = "对局结束"
		return
	if not combat.player.alive():
		order = "倒下 · 等待复活"
		return
	if combat.player.stunned > 0: return
	if attacking:
		var target: RefCounted = combat.units.get(target_id)
		if target == null or not target.alive():
			submit_stop()
		elif position.distance_to(target.position) <= combat.player.attack_range + target.radius:
			path.clear()
			order = "攻击目标"
			combat.attack(combat.player, target)
		else:
			chase_refresh -= delta
			if chase_refresh <= 0:
				chase_refresh = 0.4
				path = routing.find_approach(position, target.position, combat.player.attack_range + target.radius).slice(1)
	_move_along_path(delta)
	if path.is_empty() and order == "移动中": order = "待命"

func _move_along_path(delta: float) -> void:
	var remaining: float = combat.player.move_speed * delta
	while remaining > 0.0 and not path.is_empty():
		var distance := position.distance_to(path[0])
		if distance <= remaining:
			position = path[0]
			path.remove_at(0)
			remaining -= distance
		else:
			position = position.move_toward(path[0], remaining)
			remaining = 0.0

func _on_combat_event(event: Dictionary) -> void:
	if event.type == "death" and (event.actor == "player" or (attacking and event.actor == target_id)):
		path.clear()
		attacking = false
		order = "倒下 · 等待复活" if event.actor == "player" else "待命"
	if event.type == "respawn" and event.actor == "player":
		order = "待命"

func start_match() -> void:
	assert(match_state == null, "对局不可重复初始化")
	match_state = preload("res://simulation/lane_match.gd").new(combat, routing)
	combat.gold = 300
	target_id = ""

func current_target() -> RefCounted:
	var target: RefCounted = combat.units.get(target_id)
	if target != null and target.alive(): return target
	if match_state == null: return combat.enemy
	return combat.nearest_enemy(combat.player, INF)

func finished() -> bool:
	return match_state != null and match_state.phase == "finished"

func submit_buy(id: String) -> String:
	return economy.buy(id, finished())

func submit_sell(index: int) -> String:
	return economy.sell(index, finished())
