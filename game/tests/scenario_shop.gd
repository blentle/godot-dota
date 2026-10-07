extends RefCounted
## 通过视口输入购买和出售，验证面板命中、背包更新与输入隔离。

func run(battle: Node3D) -> bool:
	var was_processing := battle.is_physics_processing()
	battle.set_physics_process(false)
	var gold: int = battle.simulation.combat.gold
	battle.command("shop")
	if not _check(battle.hud.shop.visible and battle.hud.shop.close_button.has_focus()): return false
	await battle.get_tree().process_frame
	await _click(battle, Vector2(630, 222), MOUSE_BUTTON_LEFT)
	if not _check(battle.simulation.economy.slots[0] == "blade", "购买按钮必须提交真实交易"): return false
	if not _check(battle.simulation.combat.gold == gold - 100, "购买金币必须更新"): return false
	if not _check(battle.hud.inventory_buttons[0].text == "短剑", "背包视图必须更新"): return false
	battle.simulation.submit_stop()
	await _click(battle, Vector2(700, 300), MOUSE_BUTTON_RIGHT)
	if not _check(battle.simulation.path.is_empty(), "商店面板不得把右键传到地面"): return false
	await _click(battle, Vector2(816, 578), MOUSE_BUTTON_LEFT)
	if not _check(battle.hud.shop.selected_slot == 0, "背包点击必须选中出售槽位"): return false
	await _click(battle, Vector2(868, 358), MOUSE_BUTTON_LEFT)
	if not _check(battle.simulation.economy.slots[0].is_empty(), "出售后应清空原槽位"): return false
	if not _check(battle.simulation.combat.gold == gold - 50, "出售必须返还半价"): return false
	battle.command("menu")
	if not _check(not battle.hud.shop.visible and not battle.paused, "Esc 应先关闭商店"): return false
	battle.set_physics_process(was_processing)
	print("商店场景通过：鼠标购买、背包选择、出售和面板输入隔离。")
	return true

func _click(battle: Node3D, at: Vector2, button: int) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = button
	event.pressed = true
	battle.get_viewport().push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	battle.get_viewport().push_input(event, true)
	await battle.get_tree().process_frame

func _check(value: bool, message: String = "商店场景条件失败") -> bool:
	if not value: push_error(message)
	return value
