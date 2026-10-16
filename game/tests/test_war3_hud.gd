extends SceneTree
## 经典 HUD 行为回归：固定画布、三层状态、裁剪、鼠标提示、表格和限额浮字。

var failures := 0
var preview: Control
var hud: Control
var clicks: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	preview = preload("res://ui/war3/scenes/preview.tscn").instantiate()
	root.add_child(preview)
	preview.set_process(false)
	hud = preview.get_node("HUD")
	await process_frame
	_check(root.content_scale_size == Vector2i(1024, 768), "经典画布必须为 1024×768")
	_check(hud.size == Vector2(1024, 768), "HUD 不得沿用宽屏坐标")
	var health: Control = hud.get_node("HeroPanel/Health")
	_check(health.get_node("Clip").size.x == 192, "750/1000 血量裁剪为 192 像素")
	_check(health.get_node("Clip/Fill").size.x == 256, "裁剪不能压缩血条填充纹理")
	health.set_value(100, 0)
	_check(not health.get_node("Clip").visible, "零上限隐藏填充，不能除零")
	health.set_value(5000, 1000)
	_check(health.get_node("Clip").size.x == 256, "超上限血量不能溢出裁剪容器")
	var button: Control = hud.get_node("HeroPanel/Skill0")
	hud.skill_clicked.connect(func(index: int): clicks.append(index))
	button.set_state(2.2, false)
	button.mouse_entered.emit()
	_check(button.get_node("DISBTN").visible and not button.get_node("AHK").visible, "冷却必须使用灰度贴图遮罩且不显示高亮")
	_check(button.get_node("CooldownText").text == "3", "冷却数字向上取整")
	await _click(button)
	_check(clicks.is_empty(), "冷却中不能发出技能点击")
	button.set_state(0, true)
	_check(button.get_node("DISBTN").visible and button.get_node("CooldownText").text.is_empty(), "不可用灰图不伪造冷却数字")
	await _click(button)
	_check(clicks.is_empty(), "禁用不能发出点击")
	button.set_state(0, false)
	_check(button.get_node("AHK").visible and not button.get_node("DISBTN").visible, "正常 hover 只打开 AHK 层")
	await _click(button)
	_check(clicks == [0], "鼠标按下释放仅提交一次技能意图")
	await _tooltip(button)
	var board: Control = hud.get_node("Multiboard")
	_check(board.get_node("Row2/Icon/Dead").visible, "死亡英雄必须显示独立灰度头像")
	_check(board.get_node("Row3/Assists").text == "4", "计分板必须刷新助攻文本")
	_check(hud.get_node("TeamPortraits/Portrait1/Cooldown").text == "12", "队友大招冷却独立显示")
	board.set_players([])
	_check(not board.get_node("Row0").visible, "新数据不足十人时清理旧行")
	var map_texture: Texture2D = hud.get_node("Minimap/MapTexture").texture
	_check(map_texture is ViewportTexture and map_texture.get_size() == Vector2(256, 256), "小地图必须读取 256 方形渲染纹理")
	_pool()
	_scan(hud)
	print("经典 HUD 回归结束，失败数：", failures)
	quit(1 if failures else 0)

func _tooltip(button: Control) -> void:
	var tip: Control = hud.get_node("Tooltip")
	tip.set_process(false)
	button.mouse_exited.emit()
	button.mouse_entered.emit()
	tip._process(0.2)
	_check(not tip.visible, "悬停延迟到达前不可显示提示")
	# 高频快照重复设置相同文案，不能不断重置延迟。
	button.set_icon(button.get_node("BTN").texture, button.get_node("AHK").texture, button.get_node("DISBTN").texture, button.caption, button.description)
	tip._process(0.2)
	_check(tip.visible and tip.get_node("Title").text == button.caption, "延迟到期显示当前提示")
	button.mouse_exited.emit()
	_check(not tip.visible, "离开图标立即取消提示")
	button.mouse_entered.emit()
	button.mouse_exited.emit()
	tip._process(1)
	_check(not tip.visible, "移出后旧的延迟任务不得弹出")
	await process_frame

func _pool() -> void:
	var pool: Control = hud.get_node("FloatingTextPool")
	pool.set_process(false)
	var unit: Node3D = preview.get_node("World/Unit")
	for index in range(100): pool.damage(unit, index)
	_check(pool.get_child_count() == 64, "浮字超过容量时必须复用既有对象")
	pool._process(0.01)
	var active := 0
	for index in range(32):
		if pool.slots[index].view.visible: active += 1
	_check(active == 32, "伤害浮字最多显示 32 项")
	var alt := InputEventKey.new()
	alt.keycode = KEY_ALT
	alt.alt_pressed = true
	alt.pressed = true
	Input.parse_input_event(alt)
	Input.flush_buffered_events()
	pool._process(0)
	_check(pool.slots[32].view.visible, "按 ALT 显示单位血量")
	alt = alt.duplicate()
	alt.alt_pressed = false
	alt.pressed = false
	Input.parse_input_event(alt)
	Input.flush_buffered_events()
	pool._process(1.1)
	_check(not pool.slots[0].view.visible and not pool.slots[32].view.visible, "超时浮字和松开 ALT 的血量应隐藏")
	pool.damage(unit, 1)
	unit.free()
	pool._process(0)
	_check(not pool.slots[0].view.visible, "单位释放后不能访问已销毁对象")

func _scan(node: Node) -> void:
	if node is Control:
		_check(node.theme == null, "不应使用 Theme 资源")
		_check(node.anchor_left == 0 and node.anchor_top == 0 and node.anchor_right == 0 and node.anchor_bottom == 0, "Control 必须使用固定零锚点")
	if node is TextureRect:
		_check(node.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST or node.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE, "纹理不得线性过滤")
	for child in node.get_children(): _scan(child)

func _click(button: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.global_position + Vector2(10, 10)
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
