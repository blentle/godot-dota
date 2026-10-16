extends Control
## 交互夹具，不是游戏数据适配器；所有数值、图标和名字都明确为示例。

const BTN = preload("res://ui/war3/assets/BTN_test.png")
const AHK = preload("res://ui/war3/assets/AHK_test.png")
const DIS = preload("res://ui/war3/assets/DISBTN_test.png")
var state: Dictionary
var preview_time := 0.0

func _ready() -> void:
	# 此入口独立锁定经典 4:3 画布，不拉伸其他训练场景的坐标。
	get_window().content_scale_size = Vector2i(1024, 768)
	get_window().size = Vector2i(1024, 768)
	get_window().unresizable = true
	get_viewport().msaa_2d = Viewport.MSAA_DISABLED
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	get_viewport().use_taa = false
	state = sample_state()
	$HUD.apply_state(state)
	$HUD.skill_clicked.connect(_skill)
	$HUD.item_clicked.connect(func(index: int):
		state.items[index].cooldown = 5.0
		$HUD.apply_state(state))
	$HUD/FloatingTextPool.camera = $World/Camera3D
	$HUD/FloatingTextPool.set_health_targets([{"target": weakref($World/Unit), "hp": 750, "max_hp": 1000}])
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="): call_deferred("_capture", argument.trim_prefix("--capture="))

func sample_state() -> Dictionary:
	var people: Array = []
	for index in range(10):
		people.append({"name": "玩家 %02d" % (index + 1), "kills": index, "deaths": 2, "assists": 4,
			"gold": 500 + index * 100, "portrait": BTN, "dead_portrait": DIS,
			"alive": index != 2, "ultimate_cd": 12.0 if index == 1 else 0.0})
	var skills: Array = []
	for index in range(4):
		skills.append({"btn": BTN, "ahk": AHK, "disbtn": DIS, "title": "测试技能 %d" % (index + 1),
			"description": "用于检查原版式图标状态层。\n独立 BTN / AHK / DISBTN。\n资源未校对，不是正式英雄技能。",
			"disabled": index == 3, "cooldown": 8.0 if index == 1 else 0.0})
	var items: Array = []
	for index in range(6):
		items.append({"btn": BTN, "ahk": AHK, "disbtn": DIS, "title": "测试物品 %d" % (index + 1),
			"description": "物品说明示例。\n左键触发 5 秒冷却，仅测试表现层。", "disabled": false, "cooldown": 0.0})
	return {"hero": {"name": "英雄 HUD · 交互测试", "portrait": BTN, "hp": 750.0, "max_hp": 1000.0,
		"mp": 240.0, "max_mp": 400.0, "xp": 60.0, "xp_required": 100.0, "strength": 24, "agility": 18, "intelligence": 20},
		"gold": 1250, "lumber": 0, "team": people.slice(0, 5), "players": people, "skills": skills, "items": items}

func _process(delta: float) -> void:
	if state.is_empty(): return
	preview_time += delta
	for record in state.skills + state.items: record.cooldown = maxf(0, float(record.cooldown) - delta)
	# 只有夹具模拟时钟；实际 HUD 的冷却必须来自权威快照。
	$HUD.apply_state(state)
	$World/Unit.position.x = sin(preview_time) * 2

func _skill(index: int) -> void:
	state.skills[index].cooldown = 6.0
	$HUD/FloatingTextPool.damage($World/Unit, 125)

func _capture(path: String) -> void:
	for ignored in range(8): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit(0 if result == OK else 1)
