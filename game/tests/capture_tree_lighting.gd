extends SceneTree
## 固定画面光照诊断：仅在截图实例切换无光照材质，不修改生产材质或规则。
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://ui/war3/scenes/live_training.tscn").instantiate()
	root.add_child(scene)
	scene.battle.set_physics_process(false)
	scene.battle.camera_rig.edge_scroll = false
	scene.battle.camera_rig.zoom = 20
	scene.battle.focus = Vector3(-20, 0, 20)
	var trees := []
	_find_trees(scene, trees)
	var failed := trees.is_empty()
	for mode in range(2):
		if mode == 1:
			for tree in trees:
				for instance in tree.model.materials.instances:
					for material in instance.passes:
						material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for frame in range(12): await process_frame
		await RenderingServer.frame_post_draw
		var path := "/tmp/tree-lighting-%d.png" % mode
		failed = root.get_texture().get_image().save_png(path) != OK or failed
		print("树木光照诊断：", path, "，树木数=", trees.size())
	scene.queue_free()
	await process_frame
	quit(1 if failed else 0)
func _find_trees(node: Node, result: Array) -> void:
	if node.get_script() == load("res://presentation/classic/tree_view.gd"):
		result.append(node)
	for child in node.get_children(): _find_trees(child, result)
