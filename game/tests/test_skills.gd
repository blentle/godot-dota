extends SceneTree
## 范围与召唤回归：费用原子性、目标集合、导航、归属和生命周期。

const World = preload("res://simulation/training_world.gd")
const Unit = preload("res://simulation/combat/unit_state.gd")
var failures := 0
var serial := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func target(world: RefCounted, offset: Vector3, team: int = 1, kind: String = "creep") -> RefCounted:
	serial += 1
	var unit := Unit.new()
	unit.id = "skill_fixture_%d" % serial
	unit.team = team
	unit.kind = kind
	unit.spawn = world.position + offset
	unit.max_hp = 140
	unit.can_respawn = false
	unit.reset()
	world.combat.register(unit)
	return unit

func _initialize() -> void:
	_test_area()
	_test_rejections()
	_test_summon_combat()
	_test_follow_and_expiry()
	if failures == 0: print("代表技能测试通过：范围边界、友军建筑排除、费用、召唤寻路、归属、寿命及结束冻结。")
	quit(1 if failures else 0)

func _test_area() -> void:
	var world := World.new()
	var inside := target(world, Vector3(1, 0, 0))
	var edge := target(world, Vector3(5, 0, 0))
	var outside := target(world, Vector3(5.01, 0, 0))
	var ally := target(world, Vector3(1, 0, 1), 0)
	var tower := target(world, Vector3(1, 0, -1), 1, "tower")
	var immune := target(world, Vector3(-1, 0, 0))
	immune.invulnerable = true
	check(world.submit_skill("area").is_empty(), "范围技能应接受")
	check(inside.hp == 70 and edge.hp == 70, "范围内及边缘目标应各命中一次")
	check(outside.hp == 140 and ally.hp == 140 and tower.hp == 140 and immune.hp == 140,
		"不得命中范围外、友军、建筑或无敌目标")
	check(world.combat.player.mana == 170 and world.combat.player.area_cooldown == 8, "费用与冷却只提交一次")
	check(not world.submit_skill("area").is_empty() and inside.hp == 70, "冷却期间不能再次命中")

func _test_rejections() -> void:
	var world := World.new()
	world.combat.player.mana = 69
	check(world.submit_skill("area") == "魔法不足" and world.combat.player.area_cooldown == 0, "不足魔法不得扣费或冷却")
	world.combat.player.mana = 240
	world.combat.player.stunned = 1
	check(world.submit_skill("summon") == "单位被眩晕" and world.summons.active_id.is_empty(), "眩晕时不得召唤")
	world.combat.player.stunned = 0
	for offset in [Vector3(2, 0, 0), Vector3(-2, 0, 0), Vector3(0, 0, 2), Vector3(0, 0, -2)]:
		world.block(world.position + offset, 0)
	check(world.submit_skill("summon") == "附近没有可召唤的位置", "出生点阻塞应拒绝")
	check(world.combat.player.mana == 240 and world.combat.player.summon_cooldown == 0, "出生失败不能扣费")
	check(world.submit_skill("unknown") == "技能不存在", "未知技能必须拒绝")

func _test_summon_combat() -> void:
	var world := World.new()
	world.combat.enemy.hp = 20
	check(world.submit_skill("summon").is_empty(), "应创建守卫")
	var id: String = world.summons.active_id
	check(world.combat.player.mana == 160 and world.combat.units[id].owner_id == "player", "费用与归属错误")
	check(not world.submit_skill("summon").is_empty() and world.combat.player.mana == 160, "重复召唤不得扣费")
	world.combat.player.summon_cooldown = 0
	check(world.submit_skill("summon") == "只能同时拥有一个训练守卫", "即使冷却结束也必须检查数量上限")
	for tick in range(120): world.step(1.0 / 30)
	check(world.combat.gold == 50 and world.combat.kills == 1, "守卫应接近敌人并把补刀奖励归属玩家")
	world.combat.enemy.reset()
	world.combat.apply_damage(world.combat.enemy, world.combat.player, 9999)
	world.step(0.1)
	check(world.combat.units.has(id), "主人阵亡不应立即删除存活守卫")
	world.combat.apply_damage(world.combat.enemy, world.combat.units[id], 9999)
	world.step(0.1)
	check(not world.combat.units.has(id) and world.summons.active_id.is_empty(), "守卫死亡后必须清理")

func _test_follow_and_expiry() -> void:
	var world := World.new()
	world.combat.units.erase("enemy")
	world.submit_skill("summon")
	var id: String = world.summons.active_id
	world.block(Vector3(-22, 0, 30), 1)
	world.position = Vector3(-10, 0, 30)
	for tick in range(90): world.step(1.0 / 30)
	check(world.combat.units[id].position.distance_to(world.position) < 8, "守卫应绕过障碍跟随主人")
	world.step(15)
	check(not world.combat.units.has(id) and world.combat.gold == 0, "到期移除不能产生击杀金币")
	world = World.new()
	world.start_match()
	world.submit_skill("summon")
	world.match_state.phase = "finished"
	world.step(20)
	check(world.summons.remaining == 15 and not world.submit_skill("area").is_empty(), "结束后寿命和技能命令应冻结")
