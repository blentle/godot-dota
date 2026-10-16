extends SceneTree
## 结算装配计时工具；输出观察值，不把硬件相关耗时作为固定通过阈值。

func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var start := Time.get_ticks_msec()
	var panel := preload("res://ui/result_screen.gd").new()
	panel.snapshot = {"winner": 0, "profile": "guardian", "level": 1, "wave": 17, "seconds": 335, "gold": 635, "kills": 0, "deaths": 1, "last_hits": 0, "inventory": ["", "", "", "", "", ""]}
	root.add_child(panel)
	print("RESULT_BUILD_MS ", Time.get_ticks_msec() - start)
	await process_frame
	print("RESULT_FRAME_MS ", Time.get_ticks_msec() - start)
	quit()
