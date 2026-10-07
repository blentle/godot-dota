extends RefCounted
## 三路演练地图坐标；仅用于验证对局流程，不代表原版地图尺寸。

static func base_position(team: int) -> Vector3:
	return Vector3(-37, 0, 37) if team == 0 else Vector3(37, 0, -37)

static func tower_position(team: int, lane: int) -> Vector3:
	var points := [Vector3(-37, 0, 20), Vector3(-20, 0, 20), Vector3(-20, 0, 37)]
	return points[lane] if team == 0 else -points[2 - lane]

static func route(team: int, lane: int) -> PackedVector3Array:
	var routes := [
		PackedVector3Array([Vector3(-37, 0, 30), Vector3(-37, 0, -37), Vector3(30, 0, -37)]),
		PackedVector3Array([Vector3(-30, 0, 30), Vector3(30, 0, -30)]),
		PackedVector3Array([Vector3(-30, 0, 37), Vector3(37, 0, 37), Vector3(37, 0, -30)])]
	var result: PackedVector3Array = routes[lane].duplicate()
	if team == 1: result.reverse()
	return result
