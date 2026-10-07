extends RefCounted
## 代表技能命令：复用无副作用校验步骤，准备完成后一次提交费用和效果。

const AREA_COST := 70.0
const AREA_RADIUS := 5.0
const AREA_DAMAGE := 70.0
const AREA_COOLDOWN := 8.0
const SUMMON_COST := 80.0
const SUMMON_COOLDOWN := 20.0
var combat: RefCounted
var summons: RefCounted

func _init(rules: RefCounted, summon_rules: RefCounted) -> void:
	combat = rules
	summons = summon_rules

func reason(kind: String) -> String:
	if kind not in ["area", "summon"]: return "技能不存在"
	var actor: RefCounted = combat.player
	var context := {"actor": actor, "mana_cost": AREA_COST if kind == "area" else SUMMON_COST,
		"cooldown": actor.area_cooldown if kind == "area" else actor.summon_cooldown}
	for check in [combat.chain.check_actor, combat.chain.check_resource, combat.chain.check_cooldown]:
		var rejection: String = check.call(context)
		if not rejection.is_empty(): return rejection
	if kind == "summon" and not summons.active_id.is_empty(): return "只能同时拥有一个训练守卫"
	return ""

func cast_area() -> String:
	var rejection := reason("area")
	if not rejection.is_empty(): return rejection
	var actor: RefCounted = combat.player
	actor.mana -= AREA_COST
	actor.area_cooldown = AREA_COOLDOWN
	combat.cancel_attack(actor)
	# 固定施法中心和候选集合，命中回调不得改变本次范围判定。
	var center: Vector3 = actor.position
	var targets: Array[RefCounted] = []
	for unit in combat.units.values():
		if unit.alive() and unit.team != actor.team and unit.kind not in ["tower", "base"]:
			if unit.position.distance_to(center) <= AREA_RADIUS: targets.append(unit)
	combat.combat_event.emit({"type": "area", "actor": actor.id, "position": center})
	for unit in targets: combat.apply_damage(actor, unit, AREA_DAMAGE)
	return ""

func cast_summon() -> String:
	var rejection := reason("summon")
	if not rejection.is_empty(): return rejection
	var point: Variant = summons.spawn_point()
	if point == null: return "附近没有可召唤的位置"
	var actor: RefCounted = combat.player
	actor.mana -= SUMMON_COST
	actor.summon_cooldown = SUMMON_COOLDOWN
	combat.cancel_attack(actor)
	summons.create(point)
	combat.combat_event.emit({"type": "summon", "actor": actor.id, "position": point})
	return ""
