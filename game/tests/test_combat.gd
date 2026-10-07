extends SceneTree
## 战斗回归：校验责任链原子性、命中时机、死亡奖励和完整训练循环。

const Combat = preload("res://simulation/combat/combat_system.gd")
const World = preload("res://simulation/training_world.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func nearby() -> RefCounted:
	var combat := Combat.new()
	combat.player.position = combat.enemy.position + Vector3(1, 0, 0)
	return combat

func _initialize() -> void:
	_test_chain_atomicity()
	_test_windup_and_interrupt()
	_test_death_and_respawn()
	_test_training_loop()
	if failures == 0: print("战斗测试通过：责任链、前摇、打断、击杀、复活、追击与停止。")
	quit(1 if failures else 0)

func _test_chain_atomicity() -> void:
	var combat := Combat.new()
	check(combat.cast_strike() == "目标超出范围", "远距离施法必须拒绝")
	check(combat.player.mana == 240 and combat.player.skill_cooldown == 0, "拒绝时不得扣魔法或进入冷却")
	combat.player.position = combat.enemy.position + Vector3(1, 0, 0)
	combat.player.mana = 59
	check(combat.cast_strike() == "魔法不足", "必须校验魔法消耗")
	check(combat.enemy.hp == 240 and combat.player.mana == 59, "失败施法不得伤害目标")
	combat.player.mana = 240
	combat.attack(combat.enemy, combat.player)
	check(combat.enemy.windup > 0, "反击应进入前摇")
	check(combat.cast_strike().is_empty(), "有效施法必须成功")
	check(combat.enemy.hp == 160 and combat.player.mana == 180, "伤害与消耗必须准确提交一次")
	check(combat.enemy.stunned == 1.5 and combat.enemy.windup == 0, "眩晕必须打断前摇")
	check(not combat.cast_strike().is_empty(), "冷却期间不得重复施法")
	check(combat.player.mana == 180 and combat.enemy.hp == 160, "冷却拒绝不能产生副作用")
	combat.player.hp = 0
	check(combat.cast_strike() == "单位已倒下，等待复活", "存活校验应先于其他校验")

func _test_windup_and_interrupt() -> void:
	var combat: RefCounted = nearby()
	check(combat.attack(combat.player, combat.enemy).is_empty(), "近距离攻击应接受")
	check(combat.enemy.hp == 240, "前摇结束前不得扣血")
	combat.step(0.1)
	check(combat.enemy.hp == 240, "前摇未结束不得命中")
	combat.step(0.2)
	check(combat.enemy.hp == 185, "前摇结束应结算一次伤害")
	combat = nearby()
	combat.attack(combat.player, combat.enemy)
	combat.enemy.position += Vector3(20, 0, 0)
	combat.step(0.3)
	check(combat.enemy.hp == 240, "目标离开攻击范围必须落空")
	combat = nearby()
	combat.attack(combat.player, combat.enemy)
	combat.cancel_attack(combat.player)
	combat.step(0.3)
	check(combat.enemy.hp == 240, "取消前摇后不得命中")

func _test_death_and_respawn() -> void:
	var combat := Combat.new()
	combat.apply_damage(combat.player, combat.enemy, 1000)
	combat.apply_damage(combat.player, combat.enemy, 1000)
	check(combat.gold == 50 and combat.kills == 1, "死亡奖励必须仅结算一次")
	check(combat.enemy.hp == 0 and combat.enemy.respawn_remaining == 8, "敌方死亡状态与复活时间错误")
	combat.step(8)
	check(combat.enemy.hp == 240 and combat.enemy.position == combat.enemy.spawn, "敌方应在出生点复活")
	combat.apply_damage(combat.enemy, combat.player, 1000)
	check(combat.deaths == 1, "玩家死亡必须计数")
	check(not combat.cast_strike().is_empty(), "死亡期间不能施法")
	combat.step(5)
	check(combat.player.hp == 600 and combat.player.mana == 240, "玩家复活必须恢复资源")

func _test_training_loop() -> void:
	var world := World.new()
	check(world.submit_attack().is_empty(), "攻击命令应进入追击")
	for tick in range(180): world.step(1.0 / 30)
	check(world.combat.kills == 1 and world.combat.gold == 50, "追击与自动攻击应完成首个击杀")
	check(world.combat.player.hp < 600, "近距离对手应进行反击")
	check(not world.attacking and world.path.is_empty(), "目标死亡必须清除追击")
	for tick in range(300): world.step(1.0 / 30)
	check(world.combat.enemy.alive(), "训练对手应复活供重复测试")
	world.submit_attack()
	world.submit_stop(true)
	var hp: float = world.combat.enemy.hp
	for tick in range(60): world.step(1.0 / 30)
	check(world.combat.enemy.hp == hp and not world.attacking, "保持位置必须停止攻击")
