extends Node3D
## 相机控制器：只处理镜头投影、平移、缩放和地面坐标转换。

var camera := Camera3D.new()
var focus := Vector3(-25, 0, 24)
var zoom := 34.0
var edge_scroll := false

func _ready() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 220
	add_child(camera)
	camera.make_current()
	refresh()

func update(delta: float, paused: bool) -> void:
	if not paused:
		var direction := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_LEFT): direction.x -= 1
		if Input.is_physical_key_pressed(KEY_RIGHT): direction.x += 1
		if Input.is_physical_key_pressed(KEY_UP): direction.y -= 1
		if Input.is_physical_key_pressed(KEY_DOWN): direction.y += 1
		var mouse := get_viewport().get_mouse_position()
		var size := get_viewport().get_visible_rect().size
		if edge_scroll and DisplayServer.window_is_focused() and mouse.y > 38 and mouse.y < size.y - 194:
			if mouse.x < 12: direction.x -= 1
			if mouse.x > size.x - 12: direction.x += 1
			if mouse.y < 52: direction.y -= 1
			if mouse.y > size.y - 207: direction.y += 1
		focus += Vector3(direction.x, 0, direction.y) * delta * zoom * 0.65
		focus.x = clampf(focus.x, -44, 44)
		focus.z = clampf(focus.z, -44, 44)
	refresh()

func refresh() -> void:
	camera.size = zoom
	camera.position = focus + Vector3(0, 40, 29)
	camera.look_at(focus, Vector3.UP)

func ground_at(screen: Vector2) -> Variant:
	return Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))

func screen_position(at: Vector3) -> Vector2:
	return camera.unproject_position(at)

func scroll(button: int) -> void:
	if button == MOUSE_BUTTON_WHEEL_UP: zoom = maxf(22, zoom - 2)
	if button == MOUSE_BUTTON_WHEEL_DOWN: zoom = minf(60, zoom + 2)
