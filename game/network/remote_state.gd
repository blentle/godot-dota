extends RefCounted
## 只保存服务器数据及界面查询；不包含战斗、寻路、经济或成长模拟。

class Combat extends RefCounted:
	signal combat_event(event: Dictionary)
	var player := preload("res://simulation/combat/unit_state.gd").new()
	var enemy := preload("res://simulation/combat/unit_state.gd").new()
	var units: Dictionary = {}
	var projectiles := Projectiles.new()
	var gold := 0
	var kills := 0
	var deaths := 0
	var last_hits := 0
	func _init() -> void:
		enemy.hp = 0

class Projectiles extends RefCounted:
	var active: Dictionary = {}

class Match extends RefCounted:
	var wave := 0
	var next_wave := 0.0
	var winner := -1

class Summons extends RefCounted:
	var active_id := ""
	var remaining := 0.0

class Progression extends RefCounted:
	signal leveled(level: int)
	var player: RefCounted
	func required_experience() -> int:
		return 0 if player.level >= 10 else player.level * 100

class Availability extends RefCounted:
	var slots: Array[String] = ["", "", "", "", "", ""]
	var reasons: Dictionary = {}
	var enabled := false
	func availability(ended: bool) -> String:
		if not enabled: return "连接不可用"
		return "对局已经结束" if ended else reasons.get("shop", "等待服务器")
	func buy_reason(id: String, ended: bool) -> String:
		var blocked := availability(ended)
		return blocked if not blocked.is_empty() else reasons.get("buy", {}).get(id, "等待服务器")
	func reason(kind: String) -> String:
		return reasons.get(kind, "等待服务器") if enabled else "连接不可用"
