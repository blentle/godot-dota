extends SceneTree
## 技能升级边界、数值效果、死亡保留、网络幂等及快照恢复。

const World = preload("res://simulation/training_world.gd")
var failures := 0

func _initialize() -> void:
	var world := World.new()
	var hero: RefCounted = world.combat.player
	_check(not world.submit_upgrade("area").is_empty(), "没有点数必须拒绝")
	world.progression.grant(100)
	_check(hero.skill_points == 1, "升级发放一个点数")
	_check(not world.submit_upgrade("unknown").is_empty() and hero.skill_points == 1, "非法技能不得扣点")
	hero.area_cooldown = 4
	_check(world.submit_upgrade("area").is_empty() and hero.skill_points == 0, "合法升级扣一个点")
	_check(hero.area_cooldown == 4 and hero.mana == 240, "升级不回魔、不刷新冷却")
	world.progression.grant(200)
	_check(not world.submit_upgrade("area").is_empty() and hero.skill_points == 1, "英雄等级不足不得扣点")
	hero.hp = 0
	_check(not world.submit_upgrade("strike").is_empty() and hero.skill_points == 1, "死亡禁止升级")
	hero.reset()
	_check(hero.skill_levels.area == 2 and hero.skill_points == 1, "复活保留等级与点数")
	hero.area_cooldown = 0
	world.combat.enemy.position = hero.position + Vector3(1, 0, 0)
	var health: float = world.combat.enemy.hp
	world.submit_skill("area")
	_check(world.combat.enemy.hp == health - 95, "二级范围冲击应造成 95 开发伤害")
	_check(world.submit_upgrade("summon").is_empty(), "其他技能仍可升级")
	world.submit_skill("summon")
	var summon: RefCounted = world.combat.units[world.summons.active_id]
	_check(summon.max_hp == 240 and summon.damage == 28, "二级守卫属性只应用于新召唤物")
	world.progression.grant(99999)
	for kind in ["strike", "area", "summon"]:
		while hero.skill_levels[kind] < 4: world.submit_upgrade(kind)
	_check(hero.skill_points == 0 and not world.submit_upgrade("strike").is_empty(), "满级应消费总计九点并拒绝继续升级")
	_check(summon.max_hp == 240, "升级不能改变已存在的守卫")
	_network()
	print("技能升级测试完成，失败数：", failures)
	quit(1 if failures else 0)

func _network() -> void:
	var authority := preload("res://network/dev_authority.gd").new()
	var hello := preload("res://network/dev_protocol.gd").identity()
	hello.merge({"type": "hello", "profile": "guardian"})
	authority.receive(20, hello)
	var world: RefCounted = authority.session(20).world
	world.progression.grant(100)
	var request := {"type": "command", "match": "local-development", "sequence": 1, "command": "upgrade", "target": "strike"}
	_check(authority.receive(20, request).ok, "升级命令应通过权威入口")
	_check(authority.receive(20, request).ok and world.combat.player.skill_points == 0, "重复序号应返回缓存确认而不再次扣点")
	var packet: Dictionary = JSON.parse_string(JSON.stringify(authority.snapshot(20)))
	var remote := preload("res://network/remote_world.gd").new(preload("res://network/dev_client.gd").new())
	remote.apply(packet)
	_check(remote.combat.player.skill_levels.strike == 2 and remote.combat.player.skill_points == 0, "JSON 快照应恢复技能状态")
	_check(not remote.upgrade_reason("strike").is_empty(), "远程门面使用服务端升级拒绝原因")
	var target := preload("res://simulation/combat/unit_state.gd").new()
	target.id = "upgrade_target"
	target.team = 1
	target.spawn = world.position + Vector3(1, 0, 0)
	target.reset()
	world.combat.register(target)
	var health: float = target.hp
	_check(world.combat.cast_strike(target).is_empty(), "震击测试目标必须可施法")
	_check(target.hp == health - 110, "二级震击应造成 110 开发伤害")
	world.match_state.phase = "finished"
	_check(not world.submit_upgrade("strike").is_empty(), "结束后禁止升级")
	authority.release_peer(20)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
