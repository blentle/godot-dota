extends SceneTree
## 兵线回归：出生对称性、建筑保护、目标优先级、清理、结束冻结与长期运行。

const World = preload("res://simulation/training_world.gd")
const Factory = preload("res://simulation/lane_factory.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_test_lifecycle()
	_test_targeting()
	_test_endurance()
	if failures == 0: print("兵线测试通过：三路刷兵、索敌、保护、补刀、清理、胜负与长期运行。")
	quit(1 if failures else 0)

func _test_lifecycle() -> void:
	var world := World.new()
	world.start_match()
	var combat: RefCounted = world.combat
	check(combat.units.size() == 33, "出生应为玩家、八座建筑和二十四个小兵")
	check(not combat.units.has("enemy"), "兵线演练不能遗留自动复活的训练对手")
	var base: RefCounted = combat.units.base_1
	combat.apply_damage(combat.player, base, 9999)
	check(base.hp == 1500, "三座塔存活时基地必须受保护")
	for lane in range(3): combat.apply_damage(combat.player, combat.units["tower_1_%d" % lane], 9999)
	check(not base.invulnerable, "最后一座塔摧毁后基地应解除保护")
	check(combat.gold == 300, "建筑奖励应准确结算")
	combat.apply_damage(combat.player, base, 9999)
	check(world.finished() and world.match_state.winner == 0, "基地摧毁应判定近卫胜利")
	var elapsed: float = world.elapsed
	world.step(100)
	check(world.elapsed == elapsed and world.match_state.wave == 1, "结束后不得继续模拟或刷兵")
	check(not world.submit_move(Vector3.ZERO) and not world.submit_attack().is_empty(), "结束后应拒绝行动")

func _test_targeting() -> void:
	var world := World.new()
	world.start_match()
	var combat: RefCounted = world.combat
	var tower: RefCounted = combat.units.tower_1_1
	combat.player.position = tower.position + Vector3(3, 0, 0)
	var creep := Factory.creep(0, 1, 999, 0)
	creep.position = tower.position + Vector3(5, 0, 0)
	combat.register(creep)
	check(combat.nearest_enemy(tower, 10, true) == creep, "防御塔应优先攻击射程内小兵")
	check(combat.attack(combat.player, creep) == "不能攻击友方", "友军攻击必须拒绝")
	check(world.submit_attack(tower.id).is_empty(), "建筑中心不可行走时仍应能接近攻击")
	var victim: RefCounted = combat.units.creep_1_0_1_0
	combat.apply_damage(combat.player, victim, 9999)
	combat.apply_damage(combat.player, victim, 9999)
	check(combat.gold == 20 and combat.last_hits == 1, "小兵补刀奖励只能结算一次")
	for tick in range(130): world.step(1.0 / 30)
	check(not combat.units.has(victim.id), "死亡小兵必须清理")

func _test_endurance() -> void:
	var world := World.new()
	world.start_match()
	world.combat.player.invulnerable = true
	for tick in range(9000): world.step(1.0 / 30)
	var count := 0
	for unit in world.combat.units.values():
		if unit.kind == "creep" and unit.alive(): count += 1
		check(unit.position.is_finite(), "长期模拟不得产生非法位置")
	check(count <= 96 and world.combat.units.size() <= 129, "小兵和尸体不得无限累积")
	check(world.match_state.wave > 1, "必须持续刷兵")
	check(world.combat.units.tower_0_1.hp < 650 or world.combat.units.tower_1_1.hp < 650,
		"长期兵线应推进到防御塔并造成伤害，不能卡在路线中")
