extends SceneTree
## 商店固定画面，用于检查文本、价格、背包与状态反馈。

func _initialize() -> void:
	set_meta("lane_mode", true)
	call_deferred("_capture")

func _capture() -> void:
	var scene := preload("res://world/battlefield.gd").new()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.simulation.submit_buy("blade")
	scene.simulation.submit_buy("vest")
	scene.hud.shop.open(0)
	scene.hud.sync_state()
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if output.is_empty():
		push_error("请指定 -- --output=绝对路径")
		quit(1)
		return
	var result := root.get_texture().get_image().save_png(output)
	print("商店视觉夹具：%s，结果=%s" % [output, result])
	quit(0 if result == OK else 1)
