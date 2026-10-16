extends Control
## 固定上限浮字池：伤害最多 32 项，ALT 血量使用其余槽位；不在战斗中创建 Label。

const CAPACITY := 64
const DAMAGE_LIMIT := 32
const TEXT_SCENE = preload("res://ui/war3/scenes/floating_text.tscn")
var camera: Camera3D
var slots: Array[Dictionary] = []
var health_targets: Array[Dictionary] = []
var serial := 0

func _ready() -> void:
	for index in range(CAPACITY):
		var cell: Control = TEXT_SCENE.instantiate()
		add_child(cell)
		cell.hide()
		slots.append({"view": cell, "target": null, "life": 0.0, "serial": -1})

func damage(target: Node3D, amount: int) -> void:
	if not is_instance_valid(target): return
	var choice := 0
	for index in range(DAMAGE_LIMIT):
		if slots[index].life <= 0:
			choice = index
			break
		if slots[index].serial < slots[choice].serial: choice = index
	var slot: Dictionary = slots[choice]
	serial += 1
	slot.merge({"target": weakref(target), "life": 1.0, "serial": serial}, true)
	slot.view.get_node("Text").text = str(maxi(0, amount))
	slot.view.get_node("Text").label_settings = preload("res://ui/war3/assets/text_red.tres")

func set_health_targets(values: Array) -> void:
	# 数据中使用 WeakRef，不能因表现层持有对象而延长单位生命周期。
	health_targets.assign(values.slice(0, CAPACITY - DAMAGE_LIMIT))

func _process(delta: float) -> void:
	for index in range(DAMAGE_LIMIT):
		var slot: Dictionary = slots[index]
		slot.life = maxf(0, slot.life - delta)
		var target: Node3D = slot.target.get_ref() if slot.target != null else null
		_place(slot.view, target, slot.life > 0, (1.0 - slot.life) * 28)
	var show_health := Input.is_key_pressed(KEY_ALT)
	for index in range(CAPACITY - DAMAGE_LIMIT):
		var view: Control = slots[index + DAMAGE_LIMIT].view
		if not show_health or index >= health_targets.size():
			view.hide()
			continue
		var data: Dictionary = health_targets[index]
		var target: Node3D = data.target.get_ref()
		view.get_node("Text").text = "%d / %d" % [data.hp, data.max_hp]
		_place(view, target, true, 0)

func _place(view: Control, target: Node3D, enabled: bool, rise: float) -> void:
	if not enabled or not is_instance_valid(target) or not is_instance_valid(camera):
		view.hide()
		return
	var point := target.global_position + Vector3(0, 2.5, 0)
	if camera.is_position_behind(point):
		view.hide()
		return
	var at := camera.unproject_position(point)
	view.visible = Rect2(0, 0, 1024, 552).has_point(at)
	view.position = (at - Vector2(view.size.x / 2, rise + view.size.y)).floor()
