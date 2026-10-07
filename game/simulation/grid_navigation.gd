extends RefCounted
## 网格导航策略：静态障碍登记和路径计算，不处理战斗或界面。

const HALF_SIZE := 48
var navigation := AStarGrid2D.new()
var obstacles: Array[Vector3] = []

func _init() -> void:
	navigation.region = Rect2i(-HALF_SIZE, -HALF_SIZE, HALF_SIZE * 2 + 1, HALF_SIZE * 2 + 1)
	navigation.cell_size = Vector2.ONE
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()

func block(at: Vector3, radius: int = 1) -> void:
	obstacles.append(at)
	var center := Vector2i(roundi(at.x), roundi(at.z))
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var cell := center + Vector2i(x, y)
			if navigation.is_in_boundsv(cell):
				navigation.set_point_solid(cell)

func find_path(start_position: Vector3, target: Vector3) -> PackedVector3Array:
	var start := Vector2i(roundi(start_position.x), roundi(start_position.z))
	var finish := Vector2i(clampi(roundi(target.x), -HALF_SIZE, HALF_SIZE), clampi(roundi(target.z), -HALF_SIZE, HALF_SIZE))
	if navigation.is_point_solid(finish): return PackedVector3Array()
	var result := PackedVector3Array()
	for point in navigation.get_id_path(start, finish):
		result.append(Vector3(point.x, 0, point.y))
	return result

func find_approach(start: Vector3, target: Vector3, reach: float) -> PackedVector3Array:
	if start.distance_to(target) <= reach: return PackedVector3Array([start])
	var candidates: Array[Vector3] = []
	var extent := ceili(reach)
	for x in range(-extent, extent + 1):
		for z in range(-extent, extent + 1):
			var point := Vector3(roundf(target.x) + x, 0, roundf(target.z) + z)
			var cell := Vector2i(point.x, point.z)
			if not navigation.is_in_boundsv(cell) or navigation.is_point_solid(cell): continue
			if point.distance_to(target) <= reach: candidates.append(point)
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return start.distance_squared_to(a) < start.distance_squared_to(b))
	for point in candidates:
		var result := find_path(start, point)
		if not result.is_empty(): return result
	return PackedVector3Array()
