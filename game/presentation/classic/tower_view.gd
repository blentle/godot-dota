extends Node3D
## 防御塔原始外观：只消费规则快照及攻击事件，不参与碰撞或伤害计算。
const Model = preload("res://presentation/classic/model_view.gd")
var model: Node3D
var dead := false
var action_remaining := 0.0

func build(team: int) -> bool:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/classic/tower-catalog.json"))
	for entry in catalog.towers:
		if int(entry.team) != team or int(entry.level) != 1: continue
		model = Model.new()
		add_child(model)
		var rgb: Array = entry.color
		if not model.load_model("res://art/classic/" + entry.model,
			0 if team == 0 else 6, Color8(int(rgb[0]), int(rgb[1]), int(rgb[2]))):
			model.free()
			model = null
			return false
		model.animation_tags = PackedStringArray(entry.animation_tags)
		model.scale *= float(entry.model_scale)
		model.play("Stand", true)
		model.advance(0)
		return true
	return false

func sync_state(state: RefCounted, delta: float) -> void:
	if model == null: return
	var now_dead: bool = not state.alive()
	if now_dead != dead:
		dead = now_dead
		action_remaining = 0
		model.reset_effects()
		model.play("Death" if dead else "Stand", true)
	elif not dead:
		action_remaining = maxf(0, action_remaining - delta)
		if action_remaining <= 0: model.play("Stand")
	model.advance(maxf(0, delta))

func react(event: Dictionary) -> void:
	if model == null or dead or event.type != "swing": return
	model.play("Attack", true)
	if model.sequence >= 0:
		var interval: Array = model.data.Sequences[model.sequence].Interval
		action_remaining = (interval[1] - interval[0]) / 1000.0
