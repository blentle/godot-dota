extends SceneTree
## 成长回归：经验范围、死亡去重、连续升级、等级上限及装备组合。

const World = preload("res://simulation/training_world.gd")
const Unit = preload("res://simulation/combat/unit_state.gd")
var failures := 0
var serial := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func victim(world: RefCounted, amount: int = 30, distance: float = 1) -> RefCounted:
	serial += 1
	var unit := Unit.new()
	unit.id = "experience_fixture_%d" % serial
	unit.kind = "creep"
	unit.team = 1
	unit.experience_reward = amount
	unit.spawn = world.position + Vector3(distance, 0, 0)
	unit.can_respawn = false
	unit.reset()
	world.combat.register(unit)
	return unit

func kill(world: RefCounted, unit: RefCounted) -> void:
	world.combat.apply_damage(world.combat.player, unit, 9999)

func _initialize() -> void:
	_test_reward()
	_test_growth()
	_test_equipment_and_respawn()
	_test_finished()
	if failures == 0: print("成长测试通过：经验范围、去重、复活代次、连续升级、满级、装备与生命资源组合。")
	quit(1 if failures else 0)

func _test_reward() -> void:
	var world := World.new()
	var target := victim(world, 30, 12)
	kill(world, target)
	kill(world, target)
	world.progression.reward_death(target, false)
	check(world.combat.player.experience == 30, "范围边缘经验应发放一次")
	target.reset()
	kill(world, target)
	check(world.combat.player.experience == 60, "同标识单位的新生命死亡应能再次发奖")
	target = victim(world, 30, 12.01)
	kill(world, target)
	target.position = world.position
	world.progression.reward_death(target, false)
	check(world.combat.player.experience == 60, "范围外死亡不能事后靠近领取")
	target = victim(world)
	var ally := Unit.new()
	ally.id = "ally"
	world.combat.register(ally)
	var gold: int = world.combat.gold
	world.combat.apply_damage(ally, target, 9999)
	check(world.combat.player.experience == 90 and world.combat.gold == gold,
		"友军补刀应给附近英雄经验，但不能给英雄补刀金币")
	target = victim(world)
	world.combat.player.hp = 0
	world.combat.apply_damage(ally, target, 9999)
	check(world.combat.player.experience == 90, "阵亡英雄不能获得经验")

func _test_growth() -> void:
	var world := World.new()
	var hero: RefCounted = world.combat.player
	hero.hp = 200
	hero.mana = 50
	kill(world, victim(world, 750))
	check(hero.level == 4 and hero.experience == 150, "一次奖励应支持连续升级并保留余量")
	check(hero.damage == 73 and hero.max_hp == 840 and hero.max_mana == 330, "成长属性必须逐级累加")
	check(hero.hp == 200 and hero.mana == 50, "升级不能免费恢复资源")
	kill(world, victim(world, 100000))
	check(hero.level == 10 and hero.experience == 0 and hero.damage == 109, "等级必须封顶并停止积累经验")
	kill(world, victim(world, 100))
	check(hero.damage == 109 and world.progression.required_experience() == 0, "满级后不可重复增长")

func _test_equipment_and_respawn() -> void:
	var world := World.new()
	world.combat.gold = 1000
	world.submit_buy("blade")
	world.submit_buy("vest")
	kill(world, victim(world, 100))
	var hero: RefCounted = world.combat.player
	check(hero.damage == 73 and hero.max_hp == 830, "等级和装备属性应叠加")
	world.submit_sell(0)
	world.submit_sell(1)
	check(hero.damage == 61 and hero.max_hp == 680, "出售装备不能删除等级成长")
	world.combat.apply_damage(world.combat.enemy, hero, 9999)
	world.combat.step(5)
	check(hero.level == 2 and hero.hp == 680 and hero.mana == 270, "复活应保留成长并按新上限恢复")

func _test_finished() -> void:
	var world := World.new()
	world.start_match()
	world.match_state.phase = "finished"
	kill(world, victim(world, 100))
	check(world.combat.player.level == 1, "对局结束后不能获得经验")
	world = World.new()
	var tower := victim(world, 100)
	tower.kind = "tower"
	kill(world, tower)
	check(world.combat.player.experience == 0, "建筑暂不提供开发经验")
