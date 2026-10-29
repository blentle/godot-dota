extends SceneTree
## 原生训练 HUD 应绑定模型时钟，暂停冻结且重复刷新不重建模型。
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures+=1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene=load("res://ui/war3/scenes/live_training.tscn").instantiate()
	root.add_child(scene)
	scene.battle.set_physics_process(false)
	var clock=scene.hud.get_node("Clock")
	if not clock.has_method("sample_sequence"):
		check(false,"HUD 尚未接入模型时钟")
	else:
		clock.set_process(false)
		var original=clock.model
		var actor=scene.battle.simulation.combat.player
		var before=[actor.hp,actor.mana,actor.position]
		scene.battle.paused=true
		scene._refresh()
		var at: float=clock.model.clock
		clock.advance(1)
		check(clock.model.clock==at,"训练暂停应冻结时钟")
		scene.battle.paused=false
		scene._refresh()
		clock.advance(1)
		check(clock.model.clock>at,"恢复应继续动画")
		scene._refresh()
		check(clock.model==original,"状态刷新不得重建时钟模型")
		check(before==[actor.hp,actor.mana,actor.position],"模型时钟不得改写规则")
	scene.queue_free()
	await process_frame
	print("原始时钟 HUD 回归，失败数：",failures)
	quit(1 if failures else 0)
