extends SceneTree
## 点击选人开局，再由基地死亡进入结算并重开，避免只测试界面按钮外观。

var flow: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	flow = preload("res://bootstrap/client_flow.gd").new()
	root.add_child(flow)
	await process_frame
	if not _check(flow.phase == "selection" and flow.battle == null, "首次应停留选人，不能提前刷兵"): return
	await _click(flow.screen.cards.ranger)
	await _click(flow.screen.start_button)
	if not _check(flow.phase == "playing" and flow.battle.simulation.combat.player.profile_id == "ranger", "鼠标选人必须影响实际开局角色"): return
	flow.battle.set_physics_process(false)
	var previous: RefCounted = flow.battle.simulation
	previous.submit_buy("blade")
	previous.submit_skill("summon")
	previous.elapsed = 123
	for lane in range(3): previous.combat.apply_damage(previous.combat.player, previous.combat.units["tower_1_%d" % lane], 9999)
	previous.combat.apply_damage(previous.combat.player, previous.combat.units.base_1, 9999)
	await process_frame
	await process_frame
	if not _check(flow.phase == "result" and flow.screen.snapshot.seconds == 123, "基地死亡必须显示本局结算"): return
	if not _check(not flow.battle.is_processing_input(), "结算不能被战场快捷键穿透"): return
	await _click(flow.screen.restart_button)
	flow.battle.set_physics_process(false)
	var fresh: RefCounted = flow.battle.simulation
	if not _check(fresh != previous and fresh.combat.player.profile_id == "ranger", "重开应保留选择并新建规则世界"): return
	if not _check(fresh.economy.slots.count("") == 6 and fresh.summons.active_id.is_empty() and fresh.combat.gold == 300, "重开不得遗留装备、召唤物或金币"): return
	for lane in range(3): fresh.combat.apply_damage(fresh.combat.units.base_1, fresh.combat.units["tower_0_%d" % lane], 9999)
	fresh.combat.apply_damage(fresh.combat.units.base_1, fresh.combat.units.base_0, 9999)
	await process_frame
	await process_frame
	if not _check(flow.phase == "result" and flow.screen.snapshot.winner == 1, "本方基地死亡也必须进入失败结算"): return
	await _click(flow.screen.selection_button)
	await process_frame
	if not _check(flow.phase == "selection" and flow.battle == null, "结算按钮应能返回选择"): return
	await _click(flow.screen.mode_buttons.training)
	await _click(flow.screen.cards.apprentice)
	await _click(flow.screen.start_button)
	if not _check(flow.battle.simulation.match_state == null and flow.battle.simulation.combat.player.max_mana == 360, "训练模式应使用所选配置且没有兵线胜负"): return
	flow.battle.command("selection")
	await process_frame
	if not _check(flow.phase == "selection" and flow.battle == null, "战场菜单应能返回选择"): return
	print("会话场景通过：鼠标选人、开局、基地结算、重开清理及训练切换。")
	quit(0)

func _click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame
	await process_frame

func _check(value: bool, message: String) -> bool:
	if not value:
		push_error(message)
		quit(1)
	return value
