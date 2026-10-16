extends Control
## 老式延迟提示：离开即隐藏，延迟期间移动到另一个图标不会弹出旧提示。

@export var delay := 0.35
var owner_ref: WeakRef
var remaining := 0.0
var pending := false

func request(owner: Control, title: String, body: String) -> void:
	owner_ref = weakref(owner)
	$Title.text = title
	$Description.text = body
	remaining = delay
	pending = not title.is_empty()
	hide()

func cancel(owner: Control) -> void:
	if owner_ref != null and owner_ref.get_ref() == owner: clear()

func clear() -> void:
	owner_ref = null
	pending = false
	hide()

func _process(delta: float) -> void:
	if owner_ref == null: return
	var owner: Control = owner_ref.get_ref()
	if not is_instance_valid(owner) or not owner.is_visible_in_tree():
		clear()
		return
	if not pending: return
	remaining -= delta
	if remaining > 0: return
	pending = false
	# 提示框宽高固定；只在固定画布内调整悬浮位置，保持整数像素。
	var mouse := get_global_mouse_position()
	position = Vector2(clampf(mouse.x + 16, 0, 1024 - size.x), clampf(mouse.y - size.y - 12, 0, 768 - size.y)).floor()
	show()
