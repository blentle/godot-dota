extends SceneTree
## 通过真实视口鼠标事件校验小地图，防止点击穿透到战场和绕过移动命令。
const MapProjection = preload("res://ui/war3/scripts/minimap_projection.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var scene = load("res://ui/war3/scenes/live_training.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.battle.set_physics_process(false)
	var map: Control = scene.hud.get_node("Minimap/MapTexture")
	var renderer: Control = scene.hud.get_node("Minimap/MapViewport/Renderer")
	check(map.texture is ViewportTexture and map.texture.get_size() == Vector2(256, 256), "小地图必须保留二次幂视口纹理")
	check(not scene.hud.get_node("Minimap/MapViewport/Map").visible, "绑定真实地图后隐藏测试背景")
	check(renderer.markers.size() == 2, "单对手训练只显示两名实际存活单位")
	var actor = scene.battle.simulation.combat.player
	check(renderer.markers[0].point == MapProjection.project(actor.position, Vector2(256, 256)).floor(), "单位标记必须投影真实坐标")
	await click(map.global_position + map.size / 2, MOUSE_BUTTON_LEFT)
	check(scene.battle.focus.distance_to(Vector3.ZERO) < 0.01, "左键中心应移动镜头到世界原点")
	check(scene.battle.selected, "小地图左键不能穿透并取消单位选择")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = map.global_position + map.size / 2
	press.pressed = true
	root.push_input(press, true)
	var motion := InputEventMouseMotion.new()
	motion.position = map.global_position + map.size * 0.75
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	press = press.duplicate()
	press.position = motion.position
	press.pressed = false
	root.push_input(press, true)
	await process_frame
	check(scene.battle.focus.distance_to(Vector3(24, 0, 24)) < 0.01, "按住左键拖动必须持续更新镜头")
	check(not map.dragging, "释放左键必须结束拖拽")
	var border_focus: Vector3 = scene.battle.focus
	await click(scene.hud.get_node("Minimap").global_position + Vector2(2, 2), MOUSE_BUTTON_LEFT)
	check(scene.battle.focus == border_focus and scene.battle.selected, "边框点击不能移动镜头或穿透取消选择")
	var destination: Vector3 = actor.position + Vector3(2, 0, 0)
	await click(map.global_position + MapProjection.project(destination, map.size), MOUSE_BUTTON_RIGHT)
	check(not scene.battle.simulation.path.is_empty(), "右键应通过导航生成真实移动路径")
	var endpoint: Vector3 = scene.battle.simulation.path[-1]
	check(endpoint.distance_to(destination) < 2, "移动路径终点应对应小地图点击")
	scene.battle.simulation.submit_stop()
	scene.battle.paused = true
	var focus: Vector3 = scene.battle.focus
	await click(map.global_position + Vector2(20, 20), MOUSE_BUTTON_LEFT)
	await click(map.global_position + Vector2(20, 20), MOUSE_BUTTON_RIGHT)
	check(scene.battle.focus == focus and scene.battle.simulation.path.is_empty(), "暂停应拒绝镜头和移动指令")
	scene.battle.paused = false
	scene.battle.selected = false
	await click(map.global_position + map.size / 2, MOUSE_BUTTON_RIGHT)
	check(scene.battle.simulation.path.is_empty(), "未选中单位不能通过小地图下达移动")
	actor.hp = 0
	renderer.refresh()
	check(renderer.markers.size() == 1, "死亡单位应从小地图消失")
	actor.hp = actor.max_hp
	renderer.refresh()
	check(renderer.markers.size() == 2, "复活单位应重新显示")
	check(MapProjection.unproject(Vector2(-20, 999), map.size) == Vector3(-48, 0, 48), "拖拽越界坐标必须裁剪")
	scene.queue_free()
	await process_frame
	print("经典小地图回归，失败数：", failures)
	quit(1 if failures else 0)

func click(at: Vector2, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame
