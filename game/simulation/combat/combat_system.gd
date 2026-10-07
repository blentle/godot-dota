extends RefCounted
## 训练战斗规则：攻击前摇、技能、伤害、击杀奖励和复活。
## 参数是明确标记的开发值，不作为任何正式英雄的完成记录。

signal combat_event(event: Dictionary)

const Unit = preload("res://simulation/combat/unit_state.gd")
const Chain = preload("res://simulation/combat/command_chain.gd")
const SKILL_COST := 60.0
const SKILL_RANGE := 5.0
const SKILL_COOLDOWN := 6.0
var player := Unit.new()
var enemy := Unit.new()
var chain := Chain.new()
var units: Dictionary = {}
var projectiles := preload("res://simulation/combat/projectile_system.gd").new()
var last_hits := 0
var gold := 0
var kills := 0
var deaths := 0

func _init() -> void:
	player.id = "player"
	player.spawn = Vector3(-32, 0, 30)
	player.reset()
	enemy.id = "enemy"
	enemy.team = 1
	enemy.spawn = Vector3(-29, 0, 24)
	enemy.max_hp = 240
	enemy.max_mana = 0
	enemy.damage = 45
	enemy.attack_interval = 1.4
	enemy.reset()
	register(player)
	register(enemy)

func attack(actor: RefCounted, target: RefCounted) -> String:
	var reason := chain.validate({"actor": actor, "target": target, "range": actor.attack_range + (target.radius if target != null else 0.0),
		"mana_cost": 0.0, "cooldown": actor.attack_cooldown})
	if not reason.is_empty(): return reason
	actor.attack_cooldown = actor.attack_interval
	actor.windup = 0.28
	actor.pending_target_id = target.id
	combat_event.emit({"type": "swing", "actor": actor.id, "target": target.id})
	return ""

func cast_strike(target: RefCounted = null) -> String:
	if target == null: target = enemy
	var reason := chain.validate({"actor": player, "target": target, "range": SKILL_RANGE + target.radius,
		"mana_cost": SKILL_COST, "cooldown": player.skill_cooldown})
	if not reason.is_empty(): return reason
	player.mana -= SKILL_COST
	player.skill_cooldown = SKILL_COOLDOWN
	cancel_attack(player)
	combat_event.emit({"type": "spell", "actor": player.id, "position": player.position})
	apply_damage(player, target, 80)
	if target.alive() and target.kind not in ["base", "tower"]:
		target.stunned = 1.5
		cancel_attack(target)
	return ""

func cancel_attack(actor: RefCounted) -> void:
	actor.windup = 0
	actor.pending_target_id = ""

func step(delta: float) -> void:
	# 已存在弹道先推进，新发射弹道从下一模拟步开始飞行。
	projectiles.step(delta, units, _projectile_hit)
	for actor in units.values():
		if not actor.alive():
			actor.corpse_time += delta
			if not actor.can_respawn: continue
			actor.respawn_remaining = maxf(0, actor.respawn_remaining - delta)
			if actor.respawn_remaining == 0:
				actor.reset()
				combat_event.emit({"type": "respawn", "actor": actor.id})
			continue
		actor.attack_cooldown = maxf(0, actor.attack_cooldown - delta)
		actor.skill_cooldown = maxf(0, actor.skill_cooldown - delta)
		actor.area_cooldown = maxf(0, actor.area_cooldown - delta)
		actor.summon_cooldown = maxf(0, actor.summon_cooldown - delta)
		actor.stunned = maxf(0, actor.stunned - delta)
		actor.mana = minf(actor.max_mana, actor.mana + 3.0 * delta)
		if actor.windup > 0:
			actor.windup = maxf(0, actor.windup - delta)
			if actor.windup == 0:
				var target: RefCounted = units.get(actor.pending_target_id)
				actor.pending_target_id = ""
				if target != null and target.alive() and actor.stunned == 0:
					if actor.position.distance_to(target.position) <= actor.attack_range + target.radius:
						if actor.projectile_speed > 0:
							projectiles.launch(actor, target)
						else:
							apply_damage(actor, target, actor.damage)
	if units.has("enemy") and enemy.alive() and player.alive() and enemy.stunned == 0:
		attack(enemy, player)

func apply_damage(actor: RefCounted, target: RefCounted, amount: float) -> void:
	if not actor.alive() or not target.alive() or amount <= 0: return
	_resolve_damage(actor.owner_id if not actor.owner_id.is_empty() else actor.id, actor.team, target, amount)

func _projectile_hit(shot: Dictionary, target: RefCounted) -> void:
	_resolve_damage(shot.actor, shot.team, target, shot.damage)

func _resolve_damage(actor_id: String, team: int, target: RefCounted, amount: float) -> void:
	if not target.alive() or team == target.team or target.invulnerable: return
	target.hp = maxf(0, target.hp - amount)
	combat_event.emit({"type": "damage", "actor": actor_id, "target": target.id, "amount": amount})
	if not target.alive():
		cancel_attack(target)
		target.respawn_remaining = 5.0 if target == player else 8.0
		if actor_id == player.id:
			gold += target.reward
			if target.kind == "hero": kills += 1
			else: last_hits += 1
		elif target == player:
			deaths += 1
		combat_event.emit({"type": "death", "actor": target.id})

func register(unit: RefCounted) -> void:
	assert(not units.has(unit.id), "单位标识不能重复")
	units[unit.id] = unit

func nearest_enemy(actor: RefCounted, reach: float, prefer_creeps: bool = false) -> RefCounted:
	var best: RefCounted = null
	var score := INF
	for candidate in units.values():
		if not candidate.alive() or candidate.team == actor.team or candidate.invulnerable: continue
		var distance: float = actor.position.distance_to(candidate.position)
		if distance > reach + candidate.radius: continue
		if prefer_creeps and candidate.kind in ["creep", "summon"]: distance -= 1000.0
		if distance < score:
			score = distance
			best = candidate
	return best
