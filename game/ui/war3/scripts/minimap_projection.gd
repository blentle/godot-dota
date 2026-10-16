extends RefCounted
## 经典小地图与训练世界之间的统一投影，边界为开发地图的 [-48,48]。

static func project(world: Vector3, extent: Vector2) -> Vector2:
	return ((Vector2(world.x, world.z) + Vector2(48, 48)) / 96.0 * extent).clamp(Vector2.ZERO, extent - Vector2.ONE)

static func unproject(local: Vector2, extent: Vector2) -> Vector3:
	var point := local.clamp(Vector2.ZERO, extent) / extent * 96.0 - Vector2(48, 48)
	return Vector3(point.x, 0, point.y)
