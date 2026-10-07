extends RefCounted
## 对局生命周期：刷兵、建筑保护、清理和胜负；调用方只在进行中推进规则。

const Factory = preload("res://simulation/lane_factory.gd")
const LaneAI = preload("res://simulation/lane_ai.gd")
const WAVE_INTERVAL := 20.0
const CREEP_LIMIT := 96
var combat: RefCounted
var routing: RefCounted
var ai := LaneAI.new()
var phase := "running"
var winner := -1
var wave := 0
var next_wave := WAVE_INTERVAL

func _init(rules: RefCounted, navigation: RefCounted) -> void:
	combat = rules
	routing = navigation
	combat.units.erase("enemy")
	combat.enemy.hp = 0
	combat.enemy.can_respawn = false
	for team in range(2):
		for lane in range(-1, 3):
			var unit := Factory.building(team, lane)
			combat.register(unit)
			routing.block(unit.position, int(unit.radius))
	combat.combat_event.connect(_on_event)
	_spawn_wave()

func step(delta: float) -> void:
	if phase != "running": return
	next_wave -= delta
	if next_wave <= 0:
		next_wave += WAVE_INTERVAL
		_spawn_wave()
	ai.step(delta, combat, routing)
	for unit in combat.units.values():
		if unit.kind == "creep" and not unit.alive() and unit.corpse_time >= 4:
			combat.units.erase(unit.id)
			ai.troops.erase(unit.id)

func _spawn_wave() -> void:
	var count := 0
	for unit in combat.units.values():
		if unit.kind == "creep" and unit.alive(): count += 1
	# 整波生成，保证两边数量相等，不在上限边缘偏袒一方。
	if count + 24 > CREEP_LIMIT: return
	wave += 1
	for team in range(2):
		for lane in range(3):
			for slot in range(4):
				var unit := Factory.creep(team, lane, wave, slot)
				combat.register(unit)
				ai.enroll(unit, lane)

func _on_event(event: Dictionary) -> void:
	if event.type != "death" or phase != "running": return
	var unit: RefCounted = combat.units.get(event.actor)
	if unit == null: return
	if unit.kind == "tower":
		var protected := false
		for candidate in combat.units.values():
			if candidate.kind == "tower" and candidate.team == unit.team and candidate.alive(): protected = true
		combat.units["base_%d" % unit.team].invulnerable = protected
	elif unit.kind == "base":
		winner = 1 - unit.team
		phase = "finished"
