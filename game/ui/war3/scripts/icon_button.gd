extends Control
## 原版式 BTN/AHK/DISBTN 独立图层；只提交点击，不改权威技能或物品状态。

signal activated
signal tooltip_entered(owner: Control, title: String, description: String)
signal tooltip_exited(owner: Control)
var caption := ""
var description := ""
var cooldown := 0.0
var unavailable := false
var hovered := false
var pressed_inside := false

func _ready() -> void:
	mouse_entered.connect(_enter)
	mouse_exited.connect(_exit)
	focus_exited.connect(func(): pressed_inside = false)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): _exit())
	_refresh()

func set_icon(btn: Texture2D, ahk: Texture2D, disbtn: Texture2D, title: String, body: String) -> void:
	var changed := title != caption or body != description
	$BTN.texture = btn
	$AHK.texture = ahk
	$DISBTN.texture = disbtn
	caption = title
	description = body
	if hovered and changed: tooltip_entered.emit(self, caption, description)

func set_state(seconds: float, disabled: bool) -> void:
	# CD 由外部权威状态更新；显示层不倒计时决定技能可用性。
	cooldown = maxf(seconds, 0.0)
	unavailable = disabled
	_refresh()

func _refresh() -> void:
	# 按下期间变为冷却或禁用时取消该次点击，不能在解禁后补发。
	if unavailable or cooldown > 0: pressed_inside = false
	$BTN.visible = true
	$AHK.visible = hovered and not unavailable and cooldown <= 0
	$DISBTN.visible = unavailable or cooldown > 0
	$CooldownText.text = str(ceili(cooldown)) if cooldown > 0 else ""
	mouse_default_cursor_shape = Control.CURSOR_ARROW if unavailable or cooldown > 0 else Control.CURSOR_POINTING_HAND

func _enter() -> void:
	hovered = true
	_refresh()
	tooltip_entered.emit(self, caption, description)

func _exit() -> void:
	hovered = false
	pressed_inside = false
	_refresh()
	tooltip_exited.emit(self)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.pressed:
			pressed_inside = not unavailable and cooldown <= 0
			grab_focus()
		else:
			var allowed := pressed_inside and get_rect().has_point(position + event.position)
			pressed_inside = false
			if allowed and not unavailable and cooldown <= 0: activated.emit()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE]:
		accept_event()
		if not unavailable and cooldown <= 0: activated.emit()
