extends Control
## 固定坐标商店：展示规则拒绝原因，交易通过 submit_buy/submit_sell 提交。

signal state_changed
const Catalog = preload("res://simulation/item_catalog.gd")
const Icons = preload("res://ui/war3/scripts/training_snapshot.gd")
const IDS := ["blade", "vest", "charm", "boots"]
var battle: Node3D
var selected_slot := -1
var selected_id := ""
var previous_focus: WeakRef
var buy_buttons: Dictionary = {}

func _ready() -> void:
	$Panel/Close.get_node("Text").text = "关闭 B / Esc"
	$Panel/Close.activated.connect(close)
	$Panel/Sell.activated.connect(_sell)
	_bind_tooltip($Panel/Sell)
	for index in range(IDS.size()):
		var id: String = IDS[index]
		var row: Control = $Panel.get_node("Row%d" % index)
		row.get_node("Name").text = Catalog.ITEMS[id].name
		row.get_node("Description").text = Catalog.ITEMS[id].description
		var button: Control = row.get_node("Buy")
		button.get_node("Text").text = "%d 金 购买" % Catalog.ITEMS[id].price
		button.activated.connect(_buy.bind(id))
		buy_buttons[id] = button
		_bind_tooltip(button)
	for index in range(6):
		var button: Control = $Panel/Inventory.get_node("Slot%d" % index)
		button.activated.connect(select_slot.bind(index))
		_bind_tooltip(button)

func _bind_tooltip(button: Control) -> void:
	button.tooltip_entered.connect($Tooltip.request)
	button.tooltip_exited.connect($Tooltip.cancel)

func open(slot: int = -1) -> void:
	if not is_instance_valid(battle) or battle.paused: return
	if not visible:
		var focus: Control = get_viewport().gui_get_focus_owner()
		previous_focus = weakref(focus) if focus != null else null
	selected_slot = -1
	selected_id = ""
	$Panel/Feedback.text = ""
	battle.move_mode = false
	show()
	select_slot(slot)
	$Panel/Close.grab_focus()
	state_changed.emit()

func close() -> void:
	if not visible: return
	$Tooltip.clear()
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus): focus.release_focus()
	hide()
	var previous: Control = previous_focus.get_ref() if previous_focus != null else null
	if is_instance_valid(previous) and previous.is_visible_in_tree(): previous.grab_focus()
	previous_focus = null
	state_changed.emit()

func select_slot(index: int) -> void:
	selected_slot = index if index >= 0 and index < 6 else -1
	selected_id = battle.simulation.economy.slots[selected_slot] if selected_slot >= 0 else ""
	sync_state()

func sync_state() -> void:
	if not visible or not is_instance_valid(battle): return
	var world: RefCounted = battle.simulation
	var economy: RefCounted = world.economy
	var reason: String = "训练已暂停" if battle.paused else economy.availability(world.finished())
	$Panel/Status.text = "金币 %d · %s" % [world.combat.gold, "己方基地附近可以交易" if reason.is_empty() else reason]
	for id in buy_buttons:
		var rejection: String = "训练已暂停" if battle.paused else economy.buy_reason(id, world.finished())
		var button: Control = buy_buttons[id]
		button.set_icon(Icons.BTN, Icons.AHK, Icons.DIS, Catalog.ITEMS[id].name,
			Catalog.ITEMS[id].description + ("\n" + rejection if not rejection.is_empty() else ""))
		button.set_state(0, not rejection.is_empty())
	for index in range(6):
		var id: String = economy.slots[index]
		var item: Dictionary = Catalog.ITEMS.get(id, {})
		var button: Control = $Panel/Inventory.get_node("Slot%d" % index)
		button.set_icon(Icons.BTN, Icons.AHK, Icons.DIS, str(item.get("name", "空背包格")), str(item.get("description", "")))
		button.set_state(0, id.is_empty() or battle.paused)
	# 选中后槽位被外部状态替换时清空选择，不能出售未经再次确认的装备。
	if selected_slot >= 0 and economy.slots[selected_slot] != selected_id:
		selected_slot = -1
		selected_id = ""
	var item: Dictionary = Catalog.ITEMS.get(selected_id, {})
	$Panel/Selection.text = str(item.get("name", "未选择物品"))
	$Panel/Sell.get_node("Text").text = "出售 +%d 金" % int(item.price / 2) if not item.is_empty() else "选择物品"
	$Panel/Sell.set_icon(Icons.BTN, Icons.AHK, Icons.DIS, "出售装备", reason if not reason.is_empty() else "出售返还原价的 50%")
	$Panel/Sell.set_state(0, item.is_empty() or not reason.is_empty())

func _buy(id: String) -> void:
	if not visible or battle.paused: return
	var reason: String = battle.simulation.submit_buy(id)
	$Panel/Feedback.text = "已购买 " + Catalog.ITEMS[id].name if reason.is_empty() else reason
	sync_state()
	state_changed.emit()

func _sell() -> void:
	if not visible or battle.paused: return
	if selected_slot < 0 or selected_id.is_empty(): return
	if battle.simulation.economy.slots[selected_slot] != selected_id:
		sync_state()
		return
	var reason: String = battle.simulation.submit_sell(selected_slot)
	$Panel/Feedback.text = "物品已出售，金币已返还" if reason.is_empty() else reason
	sync_state()
	state_changed.emit()
