extends Control
## 只读对局快照，离开或重开通过会话信号处理。

signal action_requested(action: String)

const Style = preload("res://ui/session_style.gd")
const Profiles = preload("res://simulation/hero_profiles.gd")
const Items = preload("res://simulation/item_catalog.gd")
var snapshot: Dictionary
var restart_button: Button
var selection_button: Button

func _ready() -> void:
	Style.background(self)
	Style.label(self, "离线演练结算", Vector2(80, 50), 18, Style.GOLD)
	Style.label(self, "近卫胜利" if snapshot.winner == 0 else "天灾胜利", Vector2(80, 94), 42)
	Style.label(self, "%s · 等级 %d · 第 %d 波" % [Profiles.PROFILES[snapshot.profile].name, snapshot.level, snapshot.wave], Vector2(80, 159), 21, Style.GOLD)
	Style.label(self, "开发对局记录，不计入平台战绩", Vector2(80, 201), 16, Style.MUTED)
	var seconds: int = snapshot.seconds
	var values := [["对局耗时", "%02d:%02d" % [seconds / 60, seconds % 60]], ["剩余金币", str(snapshot.gold)],
		["英雄击杀", str(snapshot.kills)], ["阵亡", str(snapshot.deaths)], ["补刀 / 建筑", str(snapshot.last_hits)]]
	for index in range(values.size()):
		var x := 80 + index * 226
		Style.label(self, values[index][0], Vector2(x, 273), 17, Style.MUTED)
		Style.label(self, values[index][1], Vector2(x, 312), 34)
	Style.label(self, "结束时的装备", Vector2(80, 406), 19, Style.GOLD)
	for index in range(6):
		var id: String = snapshot.inventory[index]
		var value: String = "空格" if id.is_empty() else Items.ITEMS[id].name
		var slot := Style.button(self, value, Rect2(80 + index * 190, 448, 170, 64))
		slot.disabled = true
	selection_button = Style.button(self, "返回选人", Rect2(80, 590, 246, 58))
	selection_button.pressed.connect(func(): action_requested.emit("selection"))
	restart_button = Style.button(self, "同角色再开一局", Rect2(916, 590, 284, 58))
	restart_button.pressed.connect(func(): action_requested.emit("restart"))
	restart_button.grab_focus()
