extends RefCounted
## 复用 HUD 原生按钮样式；升级与施法分行，状态从权威门面读取。

const Training = preload("res://simulation/skill_training.gd")
var hud: Control
var buttons: Dictionary = {}
var points: Button

func build(owner_hud: Control) -> void:
	hud = owner_hud
	points = hud._button("技能点\n0", Rect2(992, 652, 62, 42), "", "训练规则：每升一级获得一个技能点")
	points.disabled = true
	var names := ["震击", "冲击", "召唤"]
	for index in range(3):
		var kind: String = Training.KINDS[index]
		var button: Button = hud._button("升级" + names[index], Rect2(1060 + index * 68, 652, 62, 42), "", "")
		button.pressed.connect(func(): _upgrade(kind))
		buttons[kind] = button

func sync() -> void:
	var battle: Node3D = hud.battle
	var world: RefCounted = battle.simulation
	var hero: RefCounted = world.combat.player
	points.text = "技能点\n%d" % hero.skill_points
	for kind in buttons:
		var rank := int(hero.skill_levels[kind])
		var reason: String = world.upgrade_reason(kind)
		if battle.paused: reason = "暂停中"
		elif not battle.selected: reason = "请先选择单位"
		var button: Button = buttons[kind]
		button.disabled = not reason.is_empty()
		button.text = "已满级\n4 / 4" if rank == 4 else "升级 +\n%d → %d" % [rank, rank + 1]
		button.tooltip_text = "训练技能 %d / 4：%s" % [rank, reason if not reason.is_empty() else "消耗 1 技能点，不刷新冷却"]
	var bonus := Training.bonus(hero, "strike")
	hud.skill_button.tooltip_text = "训练震击 %d / 4：伤害 %d；魔法 60，冷却 6 秒，眩晕 1.5 秒。" % [bonus + 1, 80 + 30 * bonus]
	bonus = Training.bonus(hero, "area")
	hud.area_button.tooltip_text = "训练冲击 %d / 4：伤害 %d；半径 5，魔法 70，冷却 8 秒。" % [bonus + 1, 70 + 25 * bonus]
	bonus = Training.bonus(hero, "summon")
	hud.summon_button.tooltip_text = "训练召唤 %d / 4：新守卫生命 %d，攻击 %d；魔法 80，冷却 20 秒，持续 15 秒。" % [bonus + 1, 180 + 60 * bonus, 20 + 8 * bonus]

func _upgrade(kind: String) -> void:
	if hud.battle.paused or not hud.battle.selected: return
	var reason: String = hud.battle.simulation.submit_upgrade(kind)
	hud.notice = "技能升级成功" if reason.is_empty() else reason
	sync()
