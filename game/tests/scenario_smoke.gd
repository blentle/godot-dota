extends RefCounted
## 场景级回归：验证装配、输入隔离和菜单状态。

func run(battle: Node3D) -> void:
	if not _check(is_instance_valid(battle.hud)):
		battle.get_tree().quit(1)
		return
	if battle.simulation.match_state != null:
		if not await preload("res://tests/scenario_shop.gd").new().run(battle):
			battle.get_tree().quit(1)
			return
		if not _check(is_instance_valid(battle.army) and battle.army.views.size() == 24):
			battle.get_tree().quit(1)
			return
		if not _check(battle.army.buildings.size() == 8):
			battle.get_tree().quit(1)
			return
		if not _check(not battle.enemy.visible):
			battle.get_tree().quit(1)
			return
		var rules: RefCounted = battle.simulation.combat
		var shooter: RefCounted = rules.units.creep_0_1_1_3
		var target: RefCounted = rules.units.creep_1_1_1_3
		rules.projectiles.launch(shooter, target)
		battle._sync_views(0)
		if not _check(battle.army.projectile_view.views.size() == 1, "真实弹道必须存在对应视图"):
			battle.get_tree().quit(1)
			return
		var shot: Dictionary = rules.projectiles.active.values()[0]
		var held_shot: Vector3 = shot.position
		battle.command("menu")
		battle._physics_process(1)
		if not _check(shot.position == held_shot, "暂停时弹道不得前进"):
			battle.get_tree().quit(1)
			return
		battle.command("menu")
		rules.projectiles.active.clear()
		battle._sync_views(0)
		if not _check(battle.army.projectile_view.views.is_empty(), "失效弹道视图必须清理"):
			battle.get_tree().quit(1)
			return
		var victim: RefCounted = battle.simulation.combat.units.creep_1_0_1_0
		battle.simulation.target_id = victim.id
		battle.command("attack")
		if not _check(battle.simulation.attacking):
			battle.get_tree().quit(1)
			return
		battle.simulation.submit_stop()
	if not _check(battle.simulation.submit_move(Vector3(-32, 0, 24))):
		battle.get_tree().quit(1)
		return
	var start: Vector3 = battle.simulation.position
	for tick in range(60): battle.simulation.step(1.0 / 30.0)
	if not _check(battle.simulation.position.distance_to(start) > 1.0):
		battle.get_tree().quit(1)
		return
	battle.simulation.submit_stop()
	if not _check(battle.simulation.path.is_empty()):
		battle.get_tree().quit(1)
		return
	battle.command("menu")
	if not _check(battle.paused and battle.hud.menu.visible):
		battle.get_tree().quit(1)
		return
	if not _check(battle.hud.resume_button.has_focus(), "暂停菜单必须获得键盘焦点"):
		battle.get_tree().quit(1)
		return
	var held: Vector3 = battle.simulation.position
	battle._physics_process(1.0)
	if not _check(battle.simulation.position == held):
		battle.get_tree().quit(1)
		return
	battle.command("menu")
	if not _check(not battle.paused and not battle.hud.menu.visible):
		battle.get_tree().quit(1)
		return
	battle.command("center")
	if not _check(battle.focus == battle.simulation.position and battle.selected):
		battle.get_tree().quit(1)
		return
	battle.selected = false
	battle.hud.sync_state()
	if not _check(battle.hud.commands[0].disabled, "未选中单位时指令必须禁用"):
		battle.get_tree().quit(1)
		return
	battle.issue_move(Vector3.ZERO)
	if not _check(battle.simulation.path.is_empty()):
		battle.get_tree().quit(1)
		return
	battle.selected = true
	var ui_click := InputEventMouseButton.new()
	ui_click.button_index = MOUSE_BUTTON_RIGHT
	ui_click.pressed = true
	ui_click.position = Vector2(440, 630)
	battle.get_viewport().push_input(ui_click, true)
	await battle.get_tree().process_frame
	if not _check(battle.simulation.path.is_empty(), "界面必须拦截移动点击"):
		battle.get_tree().quit(1)
		return
	ui_click.pressed = false
	battle.get_viewport().push_input(ui_click, true)
	if not await preload("res://tests/scenario_skills.gd").new().run(battle):
		battle.get_tree().quit(1)
		return
	print("M1 SMOKE PASS: scene, HUD input blocking, movement, stop, pause, center and selection guard")
	battle.get_tree().quit()

func _check(value: bool, message: String = "场景条件失败") -> bool:
	if not value: push_error(message)
	return value
