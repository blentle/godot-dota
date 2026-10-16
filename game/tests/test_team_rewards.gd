extends SceneTree
## 同队经验分配与私有金币；用四英雄规则世界验证，网络入口仍保持两席。

const Distribution = preload("res://simulation/experience_distribution.gd")
const Unit = preload("res://simulation/combat/unit_state.gd")
var failures := 0
var serial := 0

func _initialize() -> void:
	_test_shared()
	_test_eligibility()
	if failures == 0: print("同队奖励通过：经验守恒、资格、生命代次、入场顺序及金币归属。")
	quit(1 if failures else 0)

func _check(value: bool, reason: String) -> void:
	if not value:
		failures += 1
		push_error(reason)

func _victim(core: RefCounted, reward: int = 31) -> RefCounted:
	serial += 1
	var unit := Unit.new()
	unit.id = "reward_fixture_%d" % serial
	unit.kind = "creep"
	unit.team = 1
	unit.experience_reward = reward
	unit.reward = 40
	unit.reset()
	core.register(unit)
	return unit

func _test_shared() -> void:
	var shared := preload("res://simulation/shared_match.gd").new([0, 1, 0, 1])
	# 故意逆序入场，让敌方和较大标识先订阅事件。
	for slot in [3, 2, 1, 0]: shared.join(slot, "guardian")
	var a: RefCounted = shared.players[0]
	var b: RefCounted = shared.players[2]
	for world in shared.players.values(): world.position = Vector3.ZERO
	var victim := _victim(shared.core)
	shared.core.apply_damage(a.combat.player, victim, 9999)
	_check(a.combat.player.experience == 16 and b.combat.player.experience == 15, "奇数经验应按稳定标识均分并保留总额")
	_check(shared.players[1].combat.player.experience == 0 and shared.players[3].combat.player.experience == 0, "死者同队不能拿经验")
	_check(a.combat.gold == 340 and a.combat.last_hits == 1 and b.combat.gold == 300, "补刀金币不能随经验平分")
	shared.core.combat_event.emit({"type": "death", "actor": victim.id})
	_check(a.combat.player.experience + b.combat.player.experience == 31, "重复死亡事件不能重复分配")
	victim.reset()
	shared.core.apply_damage(b.combat.player, victim, 9999)
	_check(a.combat.player.experience == 32 and b.combat.player.experience == 30, "复活的新生命应重新分配")
	_check(b.combat.gold == 340 and b.combat.last_hits == 1, "队友补刀应记入自己账本")
	var summon := Unit.new()
	summon.id = "reward_summon"
	summon.kind = "summon"
	summon.owner_id = b.combat.player.id
	shared.core.register(summon)
	victim = _victim(shared.core, 30)
	shared.core.apply_damage(summon, victim, 9999)
	_check(b.combat.gold == 380 and b.combat.last_hits == 2 and a.combat.gold == 340, "召唤物金币只归主人")
	_check(a.combat.player.experience == 47 and b.combat.player.experience == 45, "召唤物不能成为经验分母")
	# 击杀英雄时，两名存活队友仍均分经验，击杀和死亡账本分别归属。
	var enemy: RefCounted = shared.players[1].combat.player
	enemy.experience_reward = 30
	shared.core.apply_damage(b.combat.player, enemy, 9999)
	_check(b.combat.kills == 1 and a.combat.kills == 0 and shared.players[1].combat.deaths == 1, "击杀死亡不能记入队友账本")
	_check(a.combat.player.experience == 62 and b.combat.player.experience == 60, "英雄经验应使用同一分配入口")
	shared.dispose()

func _test_eligibility() -> void:
	var core := preload("res://simulation/combat/combat_system.gd").new()
	var a := preload("res://simulation/progression_system.gd").new(core.player)
	var hero := Unit.new()
	hero.id = "teammate"
	var b := preload("res://simulation/progression_system.gd").new(hero)
	core.player.position = Vector3(12, 0, 0)
	hero.position = Vector3(12.01, 0, 0)
	var victim := _victim(core, 30)
	victim.hp = 0
	Distribution.distribute(victim, [b, a, a], false)
	_check(core.player.experience == 30 and hero.experience == 0, "边缘包含、范围外排除且重复候选不能重复分摊")
	hero.position = Vector3.ZERO
	Distribution.distribute(victim, [b, a], false)
	_check(hero.experience == 0, "事后靠近不能补领")
	victim.reset()
	victim.hp = 0
	core.player.hp = 0
	Distribution.distribute(victim, [a, b], false)
	_check(hero.experience == 30, "阵亡队友不能占用分额")
	core.player.hp = 100
	hero.level = 10
	victim.reset()
	victim.hp = 0
	Distribution.distribute(victim, [a, b], false)
	_check(core.player.experience == 60, "开发策略满级英雄不占分额")
	victim.reset()
	victim.hp = 0
	Distribution.distribute(victim, [a, b], true)
	Distribution.distribute(victim, [a, b], false)
	_check(core.player.experience == 60, "结束时不得发奖或延迟补领")
	for kind in ["tower", "summon"]:
		victim.reset()
		victim.hp = 0
		victim.kind = kind
		Distribution.distribute(victim, [a], false)
	_check(core.player.experience == 60, "建筑与召唤物死亡暂不提供经验")
