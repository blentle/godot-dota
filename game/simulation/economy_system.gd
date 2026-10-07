extends RefCounted
## 商店交易与装备属性：所有校验通过后才修改金币、背包和派生属性。

const Catalog = preload("res://simulation/item_catalog.gd")
const SHOP_POSITION := Vector3(-37, 0, 37)
const SHOP_RANGE := 11.0
var combat: RefCounted
var slots: Array[String] = ["", "", "", "", "", ""]
var bonus := {"damage": 0.0, "hp": 0.0, "mana": 0.0, "speed": 0.0}
var income_remaining := 0.0

func _init(rules: RefCounted) -> void:
	combat = rules

func availability(ended: bool) -> String:
	if ended: return "对局已经结束"
	if not combat.player.alive(): return "阵亡期间不能交易"
	if combat.player.position.distance_to(SHOP_POSITION) > SHOP_RANGE: return "请返回近卫基地附近交易"
	return ""

func buy_reason(id: String, ended: bool) -> String:
	var reason := availability(ended)
	if not reason.is_empty(): return reason
	if not Catalog.ITEMS.has(id): return "物品不存在"
	if not slots.has(""): return "背包已满，请先出售物品"
	if combat.gold < Catalog.ITEMS[id].price: return "金币不足"
	return ""

func buy(id: String, ended: bool) -> String:
	var reason := buy_reason(id, ended)
	if not reason.is_empty(): return reason
	combat.gold -= Catalog.ITEMS[id].price
	slots[slots.find("")] = id
	_recalculate()
	return ""

func sell(index: int, ended: bool) -> String:
	var reason := availability(ended)
	if not reason.is_empty(): return reason
	if index < 0 or index >= slots.size() or slots[index].is_empty(): return "请先选择背包中的物品"
	combat.gold += int(Catalog.ITEMS[slots[index]].price / 2)
	slots[index] = ""
	_recalculate()
	return ""

func step(delta: float) -> void:
	income_remaining += delta
	var earned := floori(income_remaining + 0.000001)
	combat.gold += earned
	income_remaining = maxf(0, income_remaining - earned)

func _recalculate() -> void:
	var next := {"damage": 0.0, "hp": 0.0, "mana": 0.0, "speed": 0.0}
	for id in slots:
		if id.is_empty(): continue
		var item: Dictionary = Catalog.ITEMS[id]
		for key in ["damage", "hp", "mana"]: next[key] += item[key]
		next.speed = maxf(next.speed, item.speed)
	var player: RefCounted = combat.player
	player.damage += next.damage - bonus.damage
	player.max_hp += next.hp - bonus.hp
	player.max_mana += next.mana - bonus.mana
	player.move_speed += next.speed - bonus.speed
	player.hp = minf(player.hp, player.max_hp)
	player.mana = minf(player.mana, player.max_mana)
	bonus = next
