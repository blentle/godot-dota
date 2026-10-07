extends SceneTree
## 商店回归：交易原子性、属性叠加、出售、死亡复活和持续收入。

const World = preload("res://simulation/training_world.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func setup() -> RefCounted:
	var world := World.new()
	world.combat.gold = 1000
	return world

func _initialize() -> void:
	_test_atomicity()
	_test_equipment()
	_test_lifecycle()
	if failures == 0: print("经济测试通过：交易校验、满包、叠加、资源上限、死亡复活、持续收入与结束冻结。")
	quit(1 if failures else 0)

func _test_atomicity() -> void:
	var world := setup()
	check(world.submit_buy("missing") == "物品不存在", "未知物品必须拒绝")
	check(world.combat.gold == 1000 and world.economy.slots.count("") == 6, "拒绝时不得扣费或占槽")
	world.position = Vector3.ZERO
	check(not world.submit_buy("blade").is_empty(), "远离基地不得交易")
	world.position = world.combat.player.spawn
	world.combat.gold = 99
	check(world.submit_buy("blade") == "金币不足" and world.combat.gold == 99, "余额不足不能扣款")
	world.combat.gold = 1000
	for index in range(6): check(world.submit_buy("blade").is_empty(), "六个背包格应可填满")
	check(world.submit_buy("blade").begins_with("背包已满"), "第七件物品必须拒绝")
	check(world.combat.gold == 400 and world.combat.player.damage == 127, "满包拒绝不能产生属性或金币副作用")
	check(not world.submit_sell(-1).is_empty() and not world.submit_sell(6).is_empty(), "非法槽位必须拒绝")
	check(world.submit_sell(2).is_empty(), "有效物品应能出售")
	check(world.combat.gold == 450 and world.combat.player.damage == 115, "出售应返还半价并移除一次属性")
	check(not world.submit_sell(2).is_empty() and world.combat.gold == 450, "重复出售不能重复返款")
	world.submit_buy("charm")
	check(world.economy.slots[2] == "charm", "购买应复用空槽，不移动其他物品")

func _test_equipment() -> void:
	var world := setup()
	var player: RefCounted = world.combat.player
	player.hp = 200
	player.mana = 50
	world.submit_buy("vest")
	world.submit_buy("charm")
	world.submit_buy("boots")
	world.submit_buy("boots")
	check(player.max_hp == 750 and player.hp == 200, "加生命上限不能免费治疗")
	check(player.max_mana == 320 and player.mana == 50, "加魔法上限不能免费回魔")
	check(player.move_speed == 8, "多个鞋类只取最高速度加成")
	world.submit_sell(2)
	check(player.move_speed == 8, "还有一双鞋时不能丢失速度加成")
	world.submit_sell(3)
	check(player.move_speed == 7, "最后一双鞋出售应恢复基础速度")
	player.hp = 750
	player.mana = 320
	world.submit_sell(0)
	world.submit_sell(1)
	check(player.hp == 600 and player.mana == 240, "出售降低上限时应夹取当前资源")
	var mover := setup()
	mover.submit_buy("boots")
	var start: Vector3 = mover.position
	mover.submit_move(start + Vector3(0, 0, -20))
	mover.step(1)
	check(is_equal_approx(mover.position.distance_to(start), 8), "移速装备必须影响真实导航移动")
	world.submit_buy("blade")
	player.position = world.combat.enemy.position + Vector3(1, 0, 0)
	world.combat.attack(player, world.combat.enemy)
	world.combat.step(0.3)
	check(world.combat.enemy.hp == 173, "装备攻击属性必须参与真实伤害结算")

func _test_lifecycle() -> void:
	var world := setup()
	world.submit_buy("vest")
	world.combat.apply_damage(world.combat.enemy, world.combat.player, 9999)
	check(world.submit_buy("blade") == "阵亡期间不能交易", "阵亡不能购买")
	check(world.submit_sell(0) == "阵亡期间不能交易", "阵亡不能出售")
	world.combat.step(5)
	check(world.combat.player.hp == 750 and world.economy.slots[0] == "vest", "复活保留装备并恢复装备后资源")
	world = World.new()
	world.start_match()
	check(world.combat.gold == 300, "兵线模式应发放三百初始金币")
	for tick in range(90): world.step(1.0 / 30)
	check(world.combat.gold == 303, "持续收入应按累计时间结算而非帧数")
	world.match_state.phase = "finished"
	world.step(10)
	check(world.combat.gold == 303 and not world.submit_buy("blade").is_empty(), "结束后收入和交易必须冻结")
