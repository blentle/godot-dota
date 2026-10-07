extends SceneTree
## 验证命中时机、生命周期隔离、来源快照与远程兵配置。

const Combat = preload("res://simulation/combat/combat_system.gd")
const Factory = preload("res://simulation/lane_factory.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func setup() -> RefCounted:
	var combat := Combat.new()
	combat.player.position = Vector3.ZERO
	combat.player.attack_range = 12
	combat.player.projectile_speed = 10
	combat.enemy.position = Vector3(8, 0, 0)
	combat.enemy.spawn = combat.enemy.position
	return combat

func fire(combat: RefCounted) -> void:
	check(combat.attack(combat.player, combat.enemy).is_empty(), "远程攻击应接受")
	combat.step(0.3)
	check(combat.projectiles.active.size() == 1, "前摇结束应发射弹道")
	check(combat.enemy.hp == 240, "发射不能立即扣血")

func _initialize() -> void:
	_test_flight()
	_test_life_identity()
	_test_source_snapshot()
	_test_interrupt_and_expiry()
	check(Factory.creep(0, 0, 1, 3).projectile_speed == 16, "第四名小兵应为远程兵")
	check(Factory.creep(0, 0, 1, 0).projectile_speed == 0, "前三名小兵保留近战命中")
	check(Factory.building(0, 0).projectile_speed == 20, "防御塔应使用真实弹道")
	if failures == 0: print("投射物测试通过：飞行、追踪、生命周期、死亡来源、重复命中、打断与超时。")
	quit(1 if failures else 0)

func _test_flight() -> void:
	var combat := setup()
	fire(combat)
	combat.step(0.2)
	check(combat.enemy.hp == 240, "飞行途中不得扣血")
	combat.enemy.position += Vector3(0, 0, 4)
	for tick in range(40): combat.step(1.0 / 30)
	check(combat.enemy.hp == 185, "弹道应追踪移动目标并命中一次")
	check(combat.projectiles.active.is_empty(), "命中后弹道必须清理")
	combat.step(1)
	check(combat.enemy.hp == 185, "已命中的弹道不能重复伤害")

func _test_life_identity() -> void:
	var combat := setup()
	fire(combat)
	combat.apply_damage(combat.player, combat.enemy, 999)
	combat.enemy.reset()
	combat.step(1)
	check(combat.enemy.hp == 240, "旧弹道不能命中复活后的同标识单位")
	check(combat.projectiles.active.is_empty(), "生命周期失效弹道应移除")
	combat = setup()
	fire(combat)
	combat.units.erase("enemy")
	combat.step(1)
	check(combat.projectiles.active.is_empty(), "目标被清理后弹道应失效")

func _test_source_snapshot() -> void:
	var combat := setup()
	fire(combat)
	combat.player.hp = 0
	combat.units.erase("player")
	combat.player.damage = 999
	combat.enemy.hp = 50
	combat.step(1)
	check(combat.enemy.hp == 0 and combat.gold == 50 and combat.kills == 1,
		"发射者死亡和移除后，弹道仍应使用发射快照结算归属与奖励")
	combat = setup()
	fire(combat)
	combat.player.damage = 999
	combat.step(1)
	check(combat.enemy.hp == 185, "发射后属性改变不能修改在途伤害")
	combat = setup()
	fire(combat)
	combat.enemy.invulnerable = true
	combat.step(1)
	check(combat.enemy.hp == 240, "命中时必须重新检查无敌状态")

func _test_interrupt_and_expiry() -> void:
	var combat := setup()
	combat.attack(combat.player, combat.enemy)
	combat.cancel_attack(combat.player)
	combat.step(1)
	check(combat.projectiles.active.is_empty(), "前摇取消不得发射弹道")
	combat = setup()
	fire(combat)
	combat.cancel_attack(combat.player)
	combat.enemy.position = Vector3(1000, 0, 0)
	combat.step(5)
	check(combat.projectiles.active.is_empty() and combat.enemy.hp == 240,
		"弹道超时应销毁，不能无限追踪")
