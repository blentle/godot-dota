extends SceneTree
## 防御塔定点截图：冻结训练规则，分别观察两阵营原始一级外观。
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://ui/war3/scenes/live_training.tscn").instantiate()
	root.add_child(scene)
	scene.battle.set_physics_process(false)
	scene.battle.camera_rig.edge_scroll = false
	scene.battle.camera_rig.zoom = 20
	var prefix := "/tmp/classic-tower"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-prefix="):
			prefix = argument.trim_prefix("--capture-prefix=")
	var failed := false
	for team in [0, 1]:
		var side := -1 if team == 0 else 1
		scene.battle.focus = Vector3(side * 20, 0, -side * 20)
		for frame in range(12): await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s-%d.png" % [prefix, team]
		var result := root.get_texture().get_image().save_png(path)
		failed = failed or result != OK
		print("防御塔实机截图：", path, "，结果=", result)
	scene.queue_free()
	await process_frame
	quit(1 if failed else 0)
