extends SceneTree
## 使用真实战场事件入口，检查建筑攻击路由与目标隔离。
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://ui/war3/scenes/live_training.tscn").instantiate()
	root.add_child(scene)
	var battle = scene.battle
	battle.set_physics_process(false)
	battle.simulation.start_match()
	battle._sync_views(0)
	var towers: Array = []
	for unit in battle.simulation.combat.units.values():
		if unit.kind == "tower": towers.append(unit)
	check(towers.size() == 6, "真实战场应登记六座塔")
	if towers.size() == 6:
		var actor = towers[0]
		var target = towers[1]
		var source = battle.army.building_units[actor.id]
		var other = battle.army.building_units[target.id]
		var serial: int = source.model.action_serial
		var untouched: int = other.model.action_serial
		var hp: float = target.hp
		battle.simulation.combat.combat_event.emit({"type": "swing", "actor": actor.id, "target": target.id})
		check(source.model.action_serial == serial + 1, "战场信号必须经批量视图驱动攻击者")
		check(other.model.action_serial == untouched, "攻击目标不能误播攻击动作")
		check(target.hp == hp, "表现事件不得执行伤害")
		source.sync_state(actor, 0)
		var clock: float = source.model.clock
		battle.army.sync(battle.simulation.combat, 0)
		check(source.model.clock == clock, "零时间同步不能推进建筑动画")
	scene.queue_free()
	await process_frame
	print("防御塔真实事件链检查：", failures)
	quit(0 if failures == 0 else 1)
