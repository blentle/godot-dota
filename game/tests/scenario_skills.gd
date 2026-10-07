extends RefCounted
## 用技能按钮真实点击验证施法、视图、冷却及暂停；兼容两个训练模式。

func run(battle: Node3D) -> bool:
	var processing := battle.is_physics_processing()
	battle.set_physics_process(false)
	var player: RefCounted = battle.simulation.combat.player
	var mana: float = player.mana
	battle.hud.sync_state()
	await _click(battle, Vector2(1159, 625))
	if not _check(player.area_cooldown == 8 and player.mana == mana - 70, "范围技能按钮必须提交真实施法"): return false
	await _click(battle, Vector2(1225, 625))
	var id: String = battle.simulation.summons.active_id
	if not _check(not id.is_empty() and player.mana == mana - 150, "召唤按钮必须生成守卫并扣魔法"): return false
	battle._sync_views(0)
	battle.hud.sync_state()
	if not _check(battle.army.views.has(id), "守卫必须具有对应视图"): return false
	if not _check(battle.hud.area_button.disabled and battle.hud.summon_button.disabled, "冷却时技能按钮必须禁用"): return false
	battle.command("menu")
	battle._physics_process(1)
	battle.command("area")
	if not _check(battle.simulation.summons.remaining == 15 and player.summon_cooldown == 20, "暂停必须冻结技能冷却和守卫寿命"): return false
	if not _check(player.mana == mana - 150, "暂停不得施法或扣费"): return false
	battle.command("menu")
	battle.set_physics_process(processing)
	print("技能场景通过：按钮施法、守卫视图、冷却禁用与暂停冻结。")
	return true

func _click(battle: Node3D, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	battle.get_viewport().push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	battle.get_viewport().push_input(event, true)
	await battle.get_tree().process_frame

func _check(value: bool, message: String) -> bool:
	if not value: push_error(message)
	return value
