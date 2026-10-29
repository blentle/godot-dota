extends SceneTree
## 原始时钟固定时间点实机截图；单独保存视口，避免 HUD 掩盖裁剪和透明问题。
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var clock = load("res://ui/war3/scenes/retail_clock.tscn").instantiate()
	root.add_child(clock)
	clock.paused=true
	var failed := false
	for index in range(2):
		for seconds in [0,15,30]:
			clock.sample_sequence(index,seconds)
			for frame in range(3): await process_frame
			await RenderingServer.frame_post_draw
			var result: int = clock.get_node("Viewport").get_texture().get_image().save_png("/tmp/classic-clock-%d-%d.png" % [index,seconds])
			failed = failed or result != OK
	clock.queue_free()
	await process_frame
	quit(1 if failed else 0)
