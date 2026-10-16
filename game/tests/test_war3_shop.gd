extends SceneTree
## 真实鼠标购买/出售、快捷键与拒绝路径回归；开发金币由测试夹具提供。
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
	var world: RefCounted = scene.battle.simulation
	var actor: RefCounted = world.combat.player
	var shop: Control = scene.shop
	world.combat.gold = 1000
	var original_damage: float = actor.damage
	await click(scene.get_node("Interface/ShopToggle"))
	check(shop.visible and not scene.battle.paused, "商店按钮应打开商店并保持对局运行")
	var elapsed: float = world.elapsed
	scene.battle.set_physics_process(true)
	await physics_frame
	await physics_frame
	scene.battle.set_physics_process(false)
	check(world.elapsed > elapsed, "商店打开后真实规则时钟必须继续推进")
	var mana: float = actor.mana
	await key(KEY_W)
	check(actor.mana == mana and actor.area_cooldown == 0, "商店打开时施法快捷键不能穿透")
	await pointer(Vector2(900, 450), MOUSE_BUTTON_LEFT)
	await pointer(Vector2(900, 450), MOUSE_BUTTON_RIGHT)
	check(scene.battle.selected and world.path.is_empty(), "商店外区域应阻挡取消选择和移动")
	await pointer(Vector2(50, 620), MOUSE_BUTTON_RIGHT)
	check(world.path.is_empty(), "商店应阻挡下层小地图移动")
	await click(shop.buy_buttons.blade)
	check(world.combat.gold == 900 and world.economy.slots[0] == "blade", "购买必须同步扣费并写入实际背包")
	check(actor.damage == original_damage + 12, "购买应应用装备属性")
	check(scene.hud.get_node("Resources/Gold").text == "900", "交易后 HUD 金币必须同步")
	await key(KEY_ESCAPE)
	check(not shop.visible and not scene.battle.paused, "Esc 应先关闭商店，不暂停训练")
	await click(scene.hud.get_node("HeroPanel/Item0"))
	check(shop.visible and shop.selected_slot == 0, "点击真实物品格应打开商店并选择对应物品")
	await click(shop.get_node("Panel/Sell"))
	check(world.combat.gold == 950 and world.economy.slots[0] == "", "出售应清空槽位并退还半价")
	check(actor.damage == original_damage, "出售必须撤销装备属性")
	check(shop.selected_slot == -1, "售出物品不能保留过期选择")
	await click(shop.get_node("Panel/Sell"))
	check(world.combat.gold == 950, "重复出售空槽不能重复返金")

	# 背包满、距离、死亡与暂停都必须经提交入口再次校验。
	for index in range(6): await click(shop.buy_buttons.blade)
	check(not world.economy.slots.has("") and world.combat.gold == 350, "连续购买应填满六格")
	await click(shop.buy_buttons.blade)
	shop._buy("blade")
	check(world.combat.gold == 350 and shop.get_node("Panel/Feedback").text.contains("背包已满"), "背包满时不能扣费")
	await click(shop.get_node("Panel/Inventory/Slot0"))
	await click(shop.get_node("Panel/Sell"))
	check(world.combat.gold == 400 and world.economy.slots[0] == "", "满背包应仍能选中并出售")
	actor.position = Vector3.ZERO
	shop.sync_state()
	shop._buy("vest")
	check(world.combat.gold == 400 and world.economy.slots[0] == "", "远离商店不能扣费或占用背包")
	check(shop.get_node("Panel/Feedback").text.contains("基地"), "距离拒绝必须显示原因")
	actor.position = Vector3(-37, 0, 37)
	world.combat.gold = 0
	shop.sync_state()
	await click(shop.buy_buttons.blade)
	shop._buy("blade")
	check(world.combat.gold == 0 and shop.get_node("Panel/Feedback").text == "金币不足", "金币不足应拒绝购买")
	world.combat.gold = 1000
	actor.hp = 0
	shop.sync_state()
	shop._buy("blade")
	check(world.combat.gold == 1000 and world.economy.slots[0] == "", "阵亡不能交易")
	actor.hp = actor.max_hp
	await key(KEY_F10)
	check(scene.battle.paused and not shop.visible, "F10 暂停必须关闭商店")
	shop.open()
	shop._buy("blade")
	check(not shop.visible and world.combat.gold == 1000, "暂停时不能打开商店或交易")
	await key(KEY_ESCAPE)
	await key(KEY_B)
	check(shop.visible, "B 应重新打开商店")
	await key(KEY_B)
	check(not shop.visible, "B 应关闭商店")

	# 隐藏或状态变化中的购买按钮不能补发之前按下的交易。
	shop.open()
	shop.sync_state()
	var button: Control = shop.buy_buttons.blade
	mouse_button(button.global_position + Vector2(10, 10), MOUSE_BUTTON_LEFT, true)
	actor.position = Vector3.ZERO
	shop.sync_state()
	actor.position = Vector3(-37, 0, 37)
	shop.sync_state()
	mouse_button(button.global_position + Vector2(10, 10), MOUSE_BUTTON_LEFT, false)
	check(world.combat.gold == 1000, "按钮禁用再启用不能补发旧点击")
	shop.select_slot(1)
	world.submit_sell(1)
	shop._sell()
	check(shop.selected_slot == -1 and world.combat.gold == 1050, "外部槽位变化应清除旧选择，不能重复出售")
	# 关闭再打开商店必须取消按下状态，不能在新一轮打开时补发购买。
	shop.sync_state()
	var gold_before: int = world.combat.gold
	mouse_button(button.global_position + Vector2(10, 10), MOUSE_BUTTON_LEFT, true)
	shop.close()
	shop.open()
	mouse_button(button.global_position + Vector2(10, 10), MOUSE_BUTTON_LEFT, false)
	check(world.combat.gold == gold_before, "商店隐藏再打开不能补发旧购买")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			shop.select_slot(2)
			for frame in range(8): await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(argument.trim_prefix("--capture=")) == OK, "商店截图保存失败")
	scene.queue_free()
	await process_frame
	print("经典商店回归，失败数：", failures)
	quit(1 if failures else 0)

func click(control: Control) -> void:
	await pointer(control.global_position + Vector2(10, 10), MOUSE_BUTTON_LEFT)

func pointer(at: Vector2, button: MouseButton) -> void:
	mouse_button(at, button, true)
	mouse_button(at, button, false)
	await process_frame

func mouse_button(at: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame
