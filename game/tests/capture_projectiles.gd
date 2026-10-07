extends SceneTree
## 固定弹道画面夹具；直接装配真实场景，只用于可重复的视觉检查。

func _initialize() -> void:
	set_meta("lane_mode", true)
	call_deferred("_capture")

func _capture() -> void:
	var scene := preload("res://world/battlefield.gd").new()
	root.add_child(scene)
	scene.set_physics_process(false)
	var rules: RefCounted = scene.simulation.combat
	var tower: RefCounted = rules.units.tower_0_1
	var target: RefCounted = rules.units.creep_1_1_1_0
	var archer: RefCounted = rules.units.creep_0_1_1_3
	target.position = tower.position + Vector3(8, 0, 0)
	archer.position = tower.position + Vector3(3, 0, 4)
	scene.focus = tower.position + Vector3(4, 0, 0)
	scene.camera_rig.refresh()
	rules.projectiles.launch(tower, target)
	rules.projectiles.launch(archer, target)
	rules.projectiles.step(0.18, rules.units, func(_shot, _target): pass)
	scene._sync_views(0)
	scene.hud.notice = "视觉检查：防御塔与远程兵的在途弹道"
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if output.is_empty():
		push_error("请使用 -- --output=绝对路径 指定截图位置")
		quit(1)
		return
	var result := root.get_texture().get_image().save_png(output)
	print("弹道视觉夹具：%s，结果=%s" % [output, result])
	quit(0 if result == OK else 1)
