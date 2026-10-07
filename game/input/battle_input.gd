extends RefCounted
## 输入适配器：将鼠标和键盘动作转换为场景命令，不裁定战斗结果。

func keyboard(battle: Node3D, event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode in [KEY_ESCAPE, KEY_F10]:
		battle.command("menu")
		battle.get_viewport().set_input_as_handled()
		return
	if battle.paused: return
	if event.physical_keycode == KEY_B:
		battle.command("shop")
		battle.get_viewport().set_input_as_handled()
		return
	if battle.hud.shop.visible: return
	var actions := {KEY_F1: "center", KEY_SPACE: "center", KEY_M: "move",
		KEY_S: "stop", KEY_H: "hold", KEY_A: "attack", KEY_Q: "strike", KEY_W: "area", KEY_E: "summon"}
	if actions.has(event.physical_keycode):
		battle.command(actions[event.physical_keycode])
		battle.get_viewport().set_input_as_handled()

func pointer(battle: Node3D, event: InputEvent) -> void:
	if battle.paused or not event is InputEventMouseButton or not event.pressed: return
	battle.camera_rig.scroll(event.button_index)
	var point: Variant = battle.ground_at(event.position)
	if point == null: return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		var target_id := _pick_enemy(battle, event.position)
		if not target_id.is_empty():
			battle.simulation.target_id = target_id
			battle.command("attack")
		else:
			battle.issue_move(point)
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if battle.move_mode:
			battle.issue_move(point)
		else:
			var hero_screen: Vector2 = battle.camera_rig.screen_position(battle.hero.position + Vector3(0, 1, 0))
			battle.selected = hero_screen.distance_to(event.position) < 38

func _pick_enemy(battle: Node3D, at: Vector2) -> String:
	var closest := 35.0
	var result := ""
	for unit in battle.simulation.combat.units.values():
		if not unit.alive() or unit.team == battle.simulation.combat.player.team: continue
		var screen: Vector2 = battle.camera_rig.screen_position(unit.position + Vector3(0, 1, 0))
		var distance := screen.distance_to(at)
		if distance < closest:
			closest = distance
			result = unit.id
	return result
