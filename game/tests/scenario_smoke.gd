extends RefCounted
## 场景级回归：验证装配、输入隔离和菜单状态。

func run(battle: Node3D) -> void:
	assert(is_instance_valid(battle.hud))
	if battle.simulation.match_state != null:
		await preload("res://tests/scenario_shop.gd").new().run(battle)
		assert(is_instance_valid(battle.army) and battle.army.views.size() == 24)
		assert(battle.army.buildings.size() == 8)
		assert(not battle.enemy.visible)
		var rules: RefCounted = battle.simulation.combat
		var shooter: RefCounted = rules.units.creep_0_1_1_3
		var target: RefCounted = rules.units.creep_1_1_1_3
		rules.projectiles.launch(shooter, target)
		battle._sync_views(0)
		assert(battle.army.projectile_view.views.size() == 1, "真实弹道必须存在对应视图")
		var shot: Dictionary = rules.projectiles.active.values()[0]
		var held_shot: Vector3 = shot.position
		battle.command("menu")
		battle._physics_process(1)
		assert(shot.position == held_shot, "暂停时弹道不得前进")
		battle.command("menu")
		rules.projectiles.active.clear()
		battle._sync_views(0)
		assert(battle.army.projectile_view.views.is_empty(), "失效弹道视图必须清理")
		var victim: RefCounted = battle.simulation.combat.units.creep_1_0_1_0
		battle.simulation.target_id = victim.id
		battle.command("attack")
		assert(battle.simulation.attacking)
		battle.simulation.submit_stop()
	assert(battle.simulation.submit_move(Vector3(-32, 0, 24)))
	var start: Vector3 = battle.simulation.position
	for tick in range(60): battle.simulation.step(1.0 / 30.0)
	assert(battle.simulation.position.distance_to(start) > 1.0)
	battle.simulation.submit_stop()
	assert(battle.simulation.path.is_empty())
	battle.command("menu")
	assert(battle.paused and battle.hud.menu.visible)
	assert(battle.hud.resume_button.has_focus(), "暂停菜单必须获得键盘焦点")
	var held: Vector3 = battle.simulation.position
	battle._physics_process(1.0)
	assert(battle.simulation.position == held)
	battle.command("menu")
	assert(not battle.paused and not battle.hud.menu.visible)
	battle.command("center")
	assert(battle.focus == battle.simulation.position and battle.selected)
	battle.selected = false
	battle.hud.sync_state()
	assert(battle.hud.commands[0].disabled, "未选中单位时指令必须禁用")
	battle.issue_move(Vector3.ZERO)
	assert(battle.simulation.path.is_empty())
	battle.selected = true
	var ui_click := InputEventMouseButton.new()
	ui_click.button_index = MOUSE_BUTTON_RIGHT
	ui_click.pressed = true
	ui_click.position = Vector2(440, 630)
	battle.get_viewport().push_input(ui_click, true)
	await battle.get_tree().process_frame
	assert(battle.simulation.path.is_empty(), "界面必须拦截移动点击")
	ui_click.pressed = false
	battle.get_viewport().push_input(ui_click, true)
	print("M1 SMOKE PASS: scene, HUD input blocking, movement, stop, pause, center and selection guard")
	battle.get_tree().quit()
