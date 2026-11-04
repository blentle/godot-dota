extends SceneTree
## 所有原始树木变体须能解析替换纹理，并保持静态模型可绘制。
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for north in [false, true]:
		for index in range(10 if north else 5):
			var tree = load("res://presentation/classic/tree_view.gd").new()
			root.add_child(tree)
			if not tree.build(north, index, 5):
				failures += 1
				push_error("原始树木变体加载失败")
			else:
				for entry in tree.model.data.Textures:
					var path: String = tree.model.materials.texture_path(entry)
					if not FileAccess.file_exists(path):
						failures += 1
						push_error("树木替换纹理缺失：" + path)
			tree.free()
	print("原始树木变体检查：", failures)
	quit(0 if failures == 0 else 1)
