extends Panel
## 商店组件：展示价格、交易拒绝原因与所选物品，不直接更改规则状态。

const Catalog = preload("res://simulation/item_catalog.gd")
var hud: Control
var selected_slot := -1
var buy_buttons: Dictionary = {}
var status: Label
var selection: Label
var sell_button: Button
var close_button: Button
var feedback: Label

func _ready() -> void:
	position = Vector2(256, 82)
	size = Vector2(768, 382)
	add_theme_stylebox_override("panel", hud._style(Color("202620"), hud.gold))
	_label("近卫军需商店", Vector2(24, 20), 24, hud.gold)
	_label("开发物品 · 交易期间战场继续运行", Vector2(24, 53), 13, hud.muted)
	close_button = _button("关闭  B / Esc", Rect2(604, 18, 140, 34))
	close_button.pressed.connect(close)
	status = _label("", Vector2(24, 79), 14, hud.parchment)
	var row := 0
	for id in Catalog.ITEMS:
		var item: Dictionary = Catalog.ITEMS[id]
		var y := 117 + row * 51
		_label(item.name, Vector2(24, y), 17, hud.parchment)
		_label(item.description, Vector2(24, y + 23), 12, hud.muted)
		var buy := _button("购买 %d 金" % item.price, Rect2(320, y + 3, 112, 37))
		buy.pressed.connect(func(): _buy(id))
		buy_buttons[id] = buy
		row += 1
	_label("出售装备", Vector2(480, 117), 18, hud.gold)
	_label("点击下方背包选择物品\n出售返还原价的 50%", Vector2(480, 153), 14, hud.muted)
	selection = _label("未选择物品", Vector2(480, 214), 16, hud.parchment)
	sell_button = _button("选择物品后出售", Rect2(480, 256, 264, 40))
	sell_button.pressed.connect(_sell)
	feedback = _label("", Vector2(24, 341), 14, hud.gold)
	visible = false

func _label(text: String, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_override("font", hud.font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _button(text: String, rect: Rect2) -> Button:
	var button: Button = hud._button(text, rect, "", text)
	hud.remove_child(button)
	add_child(button)
	return button

func open(slot: int = -1) -> void:
	if hud.battle.paused: return
	selected_slot = slot
	feedback.text = ""
	visible = true
	hud.battle.move_mode = false
	sync_state()
	close_button.grab_focus()

func close() -> void:
	visible = false
	close_button.release_focus()

func sync_state() -> void:
	if not visible: return
	var world: RefCounted = hud.battle.simulation
	var economy: RefCounted = world.economy
	var reason: String = economy.availability(world.finished())
	status.text = "可用金币 %d  ·  %s" % [world.combat.gold, "基地商店可以交易" if reason.is_empty() else reason]
	for id in buy_buttons:
		var rejection: String = economy.buy_reason(id, world.finished())
		buy_buttons[id].disabled = not rejection.is_empty() or hud.battle.paused
		buy_buttons[id].tooltip_text = rejection if not rejection.is_empty() else Catalog.ITEMS[id].description
	var id: String = economy.slots[selected_slot] if selected_slot >= 0 and selected_slot < 6 else ""
	selection.text = "未选择物品" if id.is_empty() else Catalog.ITEMS[id].name
	sell_button.text = "选择物品后出售" if id.is_empty() else "出售 +%d 金" % int(Catalog.ITEMS[id].price / 2)
	sell_button.disabled = id.is_empty() or not reason.is_empty() or hud.battle.paused
	sell_button.tooltip_text = reason

func _buy(id: String) -> void:
	if hud.battle.paused: return
	var reason: String = hud.battle.simulation.submit_buy(id)
	feedback.text = "已购买 " + Catalog.ITEMS[id].name if reason.is_empty() else reason
	hud.sync_state()

func _sell() -> void:
	if hud.battle.paused: return
	var reason: String = hud.battle.simulation.submit_sell(selected_slot)
	feedback.text = "物品已出售，金币已返还" if reason.is_empty() else reason
	hud.sync_state()
