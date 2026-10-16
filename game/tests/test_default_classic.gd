extends SceneTree
## 无参数启动必须看到当前经典美术，避免只在开发参数下可见而默认仍显示旧 HUD。

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var entry = load("res://bootstrap/main.tscn").instantiate()
	root.add_child(entry)
	await process_frame
	var training: Control = entry.get_child(0)
	assert(training.has_node("Interface/HUD/Console"), "默认入口没有加载原始控制台")
	assert(training.hud.console_race == "nightelf", "训练近卫必须采用地图指定的暗夜精灵皮肤")
	assert(training.hud.get_node("Console").texture != null, "默认入口不能显示缺失贴图")
	assert(root.content_scale_size == Vector2i(1024, 768), "默认画布必须固定经典 4:3 基准")
	entry.queue_free()
	await process_frame
	print("默认经典美术入口回归通过")
	quit()
