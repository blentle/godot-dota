extends RefCounted
## 图形地形与无界面服务端共用的固定树木布局，避免障碍只存在于客户端。

static func trees() -> Array[Dictionary]:
	var random := RandomNumberGenerator.new()
	random.seed = 683
	var result: Array[Dictionary] = []
	for index in range(330):
		var at := Vector3(random.randf_range(-46, 46), 0, random.randf_range(-46, 46))
		if absf(at.x + at.z) < 6 or absf(at.x - at.z) < 5 or absf(absf(at.x) - 37) < 5 or absf(absf(at.z) - 37) < 5: continue
		if at.distance_to(Vector3(-32, 0, 30)) < 7 or at.distance_to(Vector3(-29, 0, 24)) < 5: continue
		result.append({"position": at, "height": random.randf_range(3.2, 5.5)})
	return result

static func register_trees(world: RefCounted) -> void:
	for tree in trees(): world.block(tree.position)
