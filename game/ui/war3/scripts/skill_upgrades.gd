extends Control
## 经典训练 HUD 的升级入口；等级与点数来自规则，升级不刷新已有冷却。

signal state_changed
signal result_reported(message: String)
const Training = preload("res://simulation/skill_training.gd")
const Icons = preload("res://ui/war3/scripts/training_snapshot.gd")
const HOTKEYS := ["Q", "W", "E"]
const NAMES := {"strike": "震击", "area": "冲击", "summon": "召唤"}
var battle: Node3D
var blocked := false

func _ready() -> void:
	for index in range(3):
		get_node("Upgrade%d" % index).activated.connect(_upgrade.bind(Training.KINDS[index]))

func bind(value: Node3D, tooltip: Control) -> void:
	battle = value
	for index in range(3):
		var button: Control = get_node("Upgrade%d" % index)
		button.tooltip_entered.connect(tooltip.request)
		button.tooltip_exited.connect(tooltip.cancel)
	sync_state()

func _reason(kind: String) -> String:
	if blocked: return "请先关闭商店"
	if battle.paused: return "训练已暂停"
	if not battle.selected: return "请先选择单位"
	return battle.simulation.upgrade_reason(kind)

func sync_state() -> void:
	if not is_instance_valid(battle): return
	var actor: RefCounted = battle.simulation.combat.player
	$Points.text = "技能点：%d" % actor.skill_points
	for index in range(3):
		var kind: String = Training.KINDS[index]
		var rank := int(actor.skill_levels[kind])
		var reason := _reason(kind)
		var button: Control = get_node("Upgrade%d" % index)
		get_node("Rank%d" % index).text = "%s%d/%d" % [HOTKEYS[index], rank, Training.MAX_RANK]
		button.set_icon(Icons.BTN, Icons.AHK, Icons.DIS, "升级训练" + NAMES[kind],
			"当前 %d/%d 级。\n%s\n升级不回魔、不刷新冷却。\n开发成长规则，非原版英雄。" %
			[rank, Training.MAX_RANK, reason if not reason.is_empty() else "消耗 1 技能点"])
		button.set_state(0, not reason.is_empty())

func _upgrade(kind: String) -> void:
	if not is_instance_valid(battle) or kind not in Training.KINDS: return
	var reason := _reason(kind)
	if reason.is_empty(): reason = battle.simulation.submit_upgrade(kind)
	var message := reason
	if reason.is_empty():
		message = "%s已升至 %d 级" % [NAMES[kind], battle.simulation.combat.player.skill_levels[kind]]
	$Feedback.text = "升级成功" if reason.is_empty() else "升级被拒绝"
	result_reported.emit(message)
	sync_state()
	state_changed.emit()
