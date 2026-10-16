extends Control
## SubViewport 内的开发地图绘制；整数方块和非抗锯齿线段模拟低分辨率小地图。

const MapProjection = preload("res://ui/war3/scripts/minimap_projection.gd")
const Terrain = preload("res://simulation/terrain_layout.gd")
var battle: Node3D
var markers: Array[Dictionary] = []

func refresh() -> void:
	markers.clear()
	if not is_instance_valid(battle): return
	for unit in battle.simulation.combat.units.values():
		if not unit.alive(): continue
		markers.append({"id": unit.id, "point": MapProjection.project(unit.position, size).floor(),
			"team": unit.team, "kind": unit.kind,
			"local": unit.id == battle.simulation.combat.player.id})
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(battle): return
	draw_rect(Rect2(Vector2.ZERO, size), Color("314831"))
	# 河道与树木来自当前开发地图坐标；没有战争迷雾规则时不伪造视野。
	draw_line(MapProjection.project(Vector3(-48, 0, -48), size),
		MapProjection.project(Vector3(48, 0, 48), size), Color("527779"), 7, false)
	for route in Terrain.paths():
		for index in range(route.size() - 1):
			draw_line(MapProjection.project(route[index], size).floor(),
				MapProjection.project(route[index + 1], size).floor(), Color("9b9266"), 4, false)
	for obstacle in battle.simulation.obstacles:
		draw_rect(Rect2(MapProjection.project(obstacle, size).floor(), Vector2(3, 3)), Color("1c3025"))
	_draw_camera()
	for marker in markers:
		var width := 7 if marker.kind == "hero" else 5 if marker.kind in ["tower", "base"] else 3
		var color := Color("ddf681") if marker.local else Color("7ecb9a") if marker.team == battle.simulation.combat.player.team else Color("d8735d")
		draw_rect(Rect2((marker.point - Vector2.ONE * (width / 2)).floor(), Vector2.ONE * width), color)

func _draw_camera() -> void:
	var points := PackedVector2Array()
	# 此入口的可见战场为 1024×552，排除底部英雄面板。
	for corner in [Vector2.ZERO, Vector2(1024, 0), Vector2(1024, 552), Vector2(0, 552)]:
		var at: Variant = battle.ground_at(corner)
		if at != null: points.append(MapProjection.project(at, size).floor())
	if points.size() == 4:
		points.append(points[0])
		draw_polyline(points, Color.WHITE, 1, false)
