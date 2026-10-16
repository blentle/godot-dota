extends SceneTree
## 真实鼠标升级与成长提示回归；规则测试覆盖网络幂等，场景测试负责输入边界。
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
	var world: RefCounted = scene.battle.simulation
	var actor: RefCounted = world.combat.player
	var upgrades: Control = scene.upgrades
	var area: Control = upgrades.get_node("Upgrade1")
	check(upgrades.get_node("Points").text == "技能点：0", "初始点数必须来自规则")
	await click(area)
	check(actor.skill_levels.area == 1 and actor.skill_points == 0, "无点数点击不能升级")
	world.progression.grant(100)
	scene._refresh()
	check(actor.level == 2 and upgrades.get_node("Points").text == "技能点：1", "英雄成长应同步点数")
	await click(scene.hud.get_node("HeroPanel/Learn"))
	check(upgrades.visible, "原版命令卡技能加点入口必须打开学习菜单")
	actor.area_cooldown = 4
	var mana: float = actor.mana
	var gold: int = world.combat.gold
	await click(area)
	check(actor.skill_levels.area == 2 and actor.skill_points == 0, "按钮升级应提交一次并扣一个点")
	check(actor.area_cooldown == 4 and actor.mana == mana and world.combat.gold == gold, "升级不能刷新冷却或改变魔法金币")
	check(upgrades.get_node("Rank1").text == "W2/4", "技能等级标签必须立即同步")
	check(scene.hud.get_node("HeroPanel/Skill1").description.contains("伤害 95"), "升级后施法提示必须反映实际伤害")
	await click(area)
	check(actor.skill_levels.area == 2 and actor.skill_points == 0, "重复点击不能升级或出现负点数")
	await click(upgrades.get_node("Cancel"))
	check(not upgrades.visible, "取消应返回普通命令卡")
	actor.area_cooldown = 0
	world.combat.enemy.position = actor.position + Vector3(1, 0, 0)
	var health: float = world.combat.enemy.hp
	scene._refresh()
	await click(scene.hud.get_node("HeroPanel/Skill1"))
	check(world.combat.enemy.hp == health - 95, "提示中的伤害必须与真实二级施法一致")
	world.progression.grant(200)
	scene._refresh()
	check(actor.level == 3 and actor.skill_points == 1, "三级应保留一个可用点")
	await click(scene.hud.get_node("HeroPanel/Learn"))
	check(area.description.contains("需要英雄 4 级"), "等级不足必须显示准确门槛")
	await click(area)
	upgrades._upgrade("area")
	check(actor.skill_levels.area == 2 and actor.skill_points == 1, "等级不足不能扣点")
	check(scene.get_node("Interface/Notice").text.contains("需要英雄 4 级"), "命令拒绝应反馈完整原因")

	# 选择、暂停、阵亡和商店都不能绕过界面命令入口。
	scene.battle.selected = false
	scene._refresh()
	upgrades._upgrade("strike")
	check(actor.skill_levels.strike == 1 and actor.skill_points == 1, "未选中不能升级")
	scene.battle.selected = true
	scene.battle.paused = true
	scene._refresh()
	upgrades._upgrade("strike")
	check(actor.skill_levels.strike == 1, "暂停时不能升级")
	scene.battle.paused = false
	actor.hp = 0
	scene._refresh()
	upgrades._upgrade("strike")
	check(actor.skill_points == 1 and actor.skill_levels.strike == 1, "阵亡不能升级")
	actor.hp = actor.max_hp
	scene.shop.open()
	upgrades._upgrade("strike")
	check(actor.skill_points == 1 and actor.skill_levels.strike == 1, "商店打开时不能升级")
	scene.shop.close()
	scene._refresh()
	await click(scene.hud.get_node("HeroPanel/Learn"))
	var strike: Control = upgrades.get_node("Upgrade0")
	await click(strike)
	check(actor.skill_levels.strike == 2 and actor.skill_points == 0, "恢复可用状态后允许正常升级")
	check(scene.hud.get_node("HeroPanel/Skill0").description.contains("伤害 110"), "震击提示应显示成长伤害")
	world.progression.grant(99999)
	scene._refresh()
	await click(area)
	await click(area)
	var points: int = actor.skill_points
	await click(area)
	check(actor.skill_levels.area == 4 and actor.skill_points == points, "满级不能继续扣点")
	check(area.description.contains("技能已满级") and area.get_node("DISBTN").visible, "满级应展示灰图与拒绝原因")
	await click(upgrades.get_node("Upgrade2"))
	check(scene.hud.get_node("HeroPanel/Skill2").description.contains("生命 240，攻击 28"), "召唤提示应展示新守卫成长属性")

	# 在按下和松开之间切换到不可用状态，不能补发之前的升级。
	var summon: Control = upgrades.get_node("Upgrade2")
	var before: int = actor.skill_points
	mouse_button(summon.global_position + Vector2(10, 10), true)
	scene.battle.selected = false
	scene._refresh()
	scene.battle.selected = true
	scene._refresh()
	mouse_button(summon.global_position + Vector2(10, 10), false)
	check(actor.skill_points == before and actor.skill_levels.summon == 2, "恢复选择不能补发旧按下升级")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			for frame in range(8): await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(argument.trim_prefix("--capture=")) == OK, "升级界面截图保存失败")
	scene.queue_free()
	await process_frame
	print("经典技能升级回归，失败数：", failures)
	quit(1 if failures else 0)

func click(control: Control) -> void:
	mouse_button(control.global_position + Vector2(10, 10), true)
	mouse_button(control.global_position + Vector2(10, 10), false)
	await process_frame

func mouse_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)
