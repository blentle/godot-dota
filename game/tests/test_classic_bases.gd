extends SceneTree
## 基地原始模型只参与表现，死亡消费状态而不修改保护规则。
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var failures := 0
	for team in [0, 1]:
		var base = load("res://presentation/classic/base_view.gd").new()
		root.add_child(base)
		if not base.build(team): failures += 1
		else:
			var state = load("res://simulation/lane_factory.gd").building(team)
			base.sync_state(state, 0)
			var clock: float = base.model.clock
			base.sync_state(state, 0)
			if base.model.clock != clock or not state.invulnerable: failures += 1
			state.hp = 0
			base.sync_state(state, 0.1)
			if not base.dead or base.scale != Vector3.ONE: failures += 1
		base.free()
	print("原始基地外观检查：", failures)
	quit(0 if failures == 0 else 1)
