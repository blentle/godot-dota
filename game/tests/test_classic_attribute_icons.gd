extends SceneTree
## 原生属性区必须使用独立原始图标；未知属性仍为空，不伪造训练数值。
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://ui/war3/scenes/live_training.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.battle.set_physics_process(false)
	var panel: Control = scene.hud.get_node("HeroPanel/Attributes")
	for stat in ["Strength", "Agility", "Intelligence"]:
		var icon = panel.get_node_or_null(stat+"/Icon")
		if not icon is TextureRect or icon.texture == null:
			failures += 1
			push_error("缺少原始属性图标："+stat)
		elif icon.texture.get_width() <= 0:
			failures += 1
			push_error("属性图标无有效像素："+stat)
		if panel.get_node(stat+"/Value").text != "—":
			failures += 1
			push_error("未知训练属性不能填充地图基础值")
	scene.queue_free()
	await process_frame
	print("经典属性图标回归，失败数：",failures)
	quit(1 if failures else 0)
