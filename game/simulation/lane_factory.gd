extends RefCounted
## 单位创建工厂：集中保存演练参数，正式版本需替换为已校对的数据。

const Unit = preload("res://simulation/combat/unit_state.gd")
const Layout = preload("res://simulation/lane_layout.gd")

static func building(team: int, lane: int = -1) -> RefCounted:
	var unit := Unit.new()
	unit.id = "base_%d" % team if lane < 0 else "tower_%d_%d" % [team, lane]
	unit.team = team
	unit.kind = "base" if lane < 0 else "tower"
	unit.spawn = Layout.base_position(team) if lane < 0 else Layout.tower_position(team, lane)
	unit.max_hp = 1500 if lane < 0 else 650
	unit.max_mana = 0
	unit.radius = 3 if lane < 0 else 2
	unit.damage = 40
	unit.attack_range = 10
	unit.projectile_speed = 20 if lane >= 0 else 0
	unit.can_respawn = false
	unit.invulnerable = lane < 0
	unit.reward = 0 if lane < 0 else 100
	unit.reset()
	return unit

static func creep(team: int, lane: int, wave: int, slot: int) -> RefCounted:
	var unit := Unit.new()
	unit.id = "creep_%d_%d_%d_%d" % [team, lane, wave, slot]
	unit.team = team
	unit.kind = "creep"
	unit.experience_reward = 30
	unit.spawn = Layout.route(team, lane)[0] + Vector3(slot % 2, 0, floori(slot / 2.0))
	unit.max_hp = 140
	unit.max_mana = 0
	unit.damage = 14
	unit.attack_range = 1.4
	unit.attack_interval = 1.2
	if slot == 3:
		unit.role = "ranged"
		unit.max_hp = 80
		unit.damage = 18
		unit.attack_range = 6
		unit.attack_interval = 1.8
		unit.projectile_speed = 16
	unit.radius = 0.35
	unit.can_respawn = false
	unit.reward = 20
	unit.reset()
	return unit
