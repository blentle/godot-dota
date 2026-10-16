extends TextureRect
## 将显示区鼠标坐标转换成世界命令；暂停和未选中状态仍由训练入口裁定。

const MapProjection = preload("res://ui/war3/scripts/minimap_projection.gd")
var battle: Node3D
var dragging := false
var input_blocked := false
var renderer: Control

func bind(value: Node3D) -> void:
	battle = value
	renderer = get_node("../MapViewport/Renderer")
	renderer.battle = value
	get_node("../MapViewport/Map").hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	refresh()

func refresh() -> void:
	if is_instance_valid(renderer): renderer.refresh()

func _gui_input(event: InputEvent) -> void:
	if not is_instance_valid(battle): return
	if input_blocked:
		dragging = false
		accept_event()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed and not battle.paused
			if dragging: _center(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not battle.paused:
			battle.issue_move(MapProjection.unproject(event.position, size))
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		if not battle.paused and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_center(event.position)
		else: dragging = false
		accept_event()

func _center(at: Vector2) -> void:
	# 相机与现有镜头控制器一致，不能拖出训练地图允许的镜头范围。
	var point := MapProjection.unproject(at, size)
	battle.focus = Vector3(clampf(point.x, -44, 44), 0, clampf(point.z, -44, 44))
	battle.camera_rig.refresh()
	refresh()
