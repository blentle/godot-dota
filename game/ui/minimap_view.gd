extends Control
## 小地图组件：独立处理地图投影、视野框、单位标记和鼠标交互。

var battle: Node3D
var bounds := Rect2(0, 0, 168, 168)

func _ready() -> void:
	position = Vector2(14, 535)
	size = bounds.size
	mouse_filter = Control.MOUSE_FILTER_STOP

func map_point(point: Vector3) -> Vector2:
	return (Vector2(point.x, point.z) + Vector2(48, 48)) / 96 * bounds.size

func _gui_input(event: InputEvent) -> void:
	if battle.paused: return
	if event is InputEventMouseButton and event.pressed:
		var at: Vector2 = event.position / bounds.size * 96 - Vector2(48, 48)
		if event.button_index == MOUSE_BUTTON_LEFT:
			battle.focus = Vector3(at.x, 0, at.y)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			battle.issue_move(Vector3(at.x, 0, at.y))

func _draw() -> void:
	draw_rect(bounds.grow(3), Color("7f765a"), false, 2)
	draw_rect(bounds, Color("314831"))
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(168, 0), Vector2(168, 168)]), Color("404139"))
	draw_line(map_point(Vector3(-48, 0, -48)), map_point(Vector3(48, 0, 48)), Color("527779"), 6)
	var lanes := [[Vector3(-37, 0, 37), Vector3(-37, 0, -37), Vector3(37, 0, -37)],
		[Vector3(-37, 0, 37), Vector3(37, 0, -37)],
		[Vector3(-37, 0, 37), Vector3(37, 0, 37), Vector3(37, 0, -37)]]
	for lane in lanes:
		for i in range(lane.size() - 1):
			draw_line(map_point(lane[i]), map_point(lane[i + 1]), Color("9b9266"), 3)
	for obstacle in battle.simulation.obstacles:
		draw_circle(map_point(obstacle), 1.3, Color("1c3025"))
	draw_rect(Rect2(map_point(Vector3(-37, 0, 37)) - Vector2(4, 4), Vector2(8, 8)), Color("7ecb9a"))
	draw_rect(Rect2(map_point(Vector3(37, 0, -37)) - Vector2(4, 4), Vector2(8, 8)), Color("d8735d"))
	var view := PackedVector2Array()
	for corner in [Vector2(0, 38), Vector2(1280, 38), Vector2(1280, 522), Vector2(0, 522)]:
		var world: Variant = battle.ground_at(corner)
		if world != null:
			view.append(map_point(world).clamp(Vector2.ZERO, bounds.size))
	if view.size() == 4:
		view.append(view[0])
		draw_polyline(view, Color("c9c9b1"), 1)
	if battle.simulation.combat.player.alive():
		draw_circle(map_point(battle.simulation.position), 3.5, Color("ddf681"))
	if battle.simulation.combat.enemy.alive():
		draw_circle(map_point(battle.simulation.combat.enemy.position), 3, Color("e1816b"))

	for unit in battle.simulation.combat.units.values():
		if not unit.alive() or unit.id in ["player", "enemy"]: continue
		var color := Color("7ecb9a") if unit.team == 0 else Color("d8735d")
		draw_circle(map_point(unit.position), 2 if unit.kind == "creep" else 3, color)
