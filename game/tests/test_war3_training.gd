extends SceneTree
## 验证真实规则经适配器进入 HUD；施法、暂停和空缺字段不能被演示数据覆盖。
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	var scene = load("res://ui/war3/scenes/live_training.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.battle.set_physics_process(false)
	var actor = scene.battle.simulation.combat.player
	var mana: float = actor.mana
	scene.hud.skill_clicked.emit(1)
	check(actor.mana == mana - 70, "按钮必须经过规则扣除魔法")
	check(actor.area_cooldown > 0, "施法必须产生权威冷却")
	check(scene.hud.get_node("HeroPanel/Skill1/DISBTN").visible, "权威冷却必须显示灰图")
	scene.hud.skill_clicked.emit(1)
	check(actor.mana == mana - 70, "冷却期间不能重复扣费")
	var snapshot = scene.adapter.read(scene.battle.simulation, true, false)
	check(snapshot.hero.hp == actor.hp and snapshot.gold == scene.battle.simulation.combat.gold, "生命金币必须读取规则")
	check(not snapshot.hero.has("strength") and not snapshot.players[0].has("assists"), "缺失属性助攻不能伪造")
	check(snapshot.skills[3].disabled and snapshot.players.size() == 1, "不能伪造第四技能或玩家")
	scene.battle.paused = true
	scene.hud.skill_clicked.emit(2)
	check(actor.summon_cooldown == 0, "暂停不能施法")
	actor.hp = 0
	snapshot = scene.adapter.read(scene.battle.simulation, true, false)
	check(not snapshot.team[0].alive and snapshot.skills[0].disabled, "死亡状态必须同步")
	scene.queue_free()
	await process_frame
	print("经典 HUD 真实训练回归，失败数：", failures)
	quit(1 if failures else 0)
