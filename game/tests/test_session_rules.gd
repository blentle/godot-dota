extends SceneTree
## 会话规则：配置合法性、角色差异、胜负冻结与结算快照隔离。

const World = preload("res://simulation/training_world.gd")
const Unit = preload("res://simulation/combat/unit_state.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_test_profiles()
	_test_snapshot()
	_test_simultaneous_hits()
	if failures == 0: print("会话规则通过：角色配置、开局锁定、结算隔离与同帧胜负冻结。")
	quit(1 if failures else 0)

func _test_profiles() -> void:
	var world := World.new()
	check(not world.configure_hero("missing").is_empty() and world.combat.player.max_hp == 600, "非法配置不得更改角色")
	check(world.configure_hero("ranger").is_empty(), "应能选择射手")
	var hero: RefCounted = world.combat.player
	check(hero.hp == 450 and hero.attack_range == 7 and hero.projectile_speed == 18, "射手实际规则必须符合选择面板")
	hero.position = world.combat.enemy.position + Vector3(6, 0, 0)
	check(world.submit_attack().is_empty(), "射手应能接受远程攻击")
	world.step(1.0 / 30)
	world.step(0.3)
	check(world.combat.projectiles.active.size() == 1 and world.combat.enemy.hp == 240, "射手普通攻击必须使用实际弹道")
	check(not world.configure_hero("guardian").is_empty(), "运行后不得切换配置")
	world = World.new()
	world.configure_hero("apprentice")
	check(world.combat.player.mana == 360 and world.combat.player.move_speed == 6.5, "学徒资源与速度必须生效")
	world.start_match()
	check(not world.configure_hero("guardian").is_empty(), "兵线初始化后不得重新配置")
	check(world.result_snapshot().is_empty(), "进行中不能生成胜负结算")

func _test_snapshot() -> void:
	var world := World.new()
	world.configure_hero("ranger")
	world.start_match()
	world.submit_buy("blade")
	world.elapsed = 125
	for lane in range(3): world.combat.apply_damage(world.combat.player, world.combat.units["tower_1_%d" % lane], 9999)
	world.combat.apply_damage(world.combat.player, world.combat.units.base_1, 9999)
	var result := world.result_snapshot()
	check(result.winner == 0 and result.seconds == 125 and result.profile == "ranger", "结算应准确记录胜方、时长和角色")
	check(result.inventory[0] == "blade" and result.gold == 500, "结算必须包含装备与余额")
	result.inventory[0] = ""
	result.gold = 0
	check(world.result_snapshot().inventory[0] == "blade" and world.result_snapshot().gold == 500, "界面修改副本不能改变已记录结果")
	var hp: float = world.combat.player.hp
	world.combat.apply_damage(world.combat.units.tower_1_0, world.combat.player, 9999)
	world.step(10)
	check(world.combat.player.hp == hp and world.elapsed == 125, "结束后规则不得继续改变")

func _test_simultaneous_hits() -> void:
	var world := World.new()
	world.start_match()
	var foe := Unit.new()
	foe.id = "end_fixture"
	foe.team = 1
	foe.projectile_speed = 20
	world.combat.register(foe)
	for lane in range(3):
		world.combat.apply_damage(world.combat.player, world.combat.units["tower_1_%d" % lane], 9999)
		world.combat.apply_damage(foe, world.combat.units["tower_0_%d" % lane], 9999)
	var near: RefCounted = world.combat.units.base_0
	var far: RefCounted = world.combat.units.base_1
	near.hp = 40
	far.hp = 40
	world.combat.player.projectile_speed = 20
	world.position = far.position + Vector3(1, 0, 0)
	foe.position = near.position + Vector3(1, 0, 0)
	world.combat.projectiles.launch(world.combat.player, far)
	world.combat.projectiles.launch(foe, near)
	world.combat.step(1)
	check(world.match_state.winner == 0 and near.hp == 40, "首个基地死亡后，同帧后续命中不得再改变胜负或伤害")
