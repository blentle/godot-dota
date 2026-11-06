extends "res://presentation/classic/tower_view.gd"
## 地图基地原始外观：复用建筑生命周期，不改写训练基地保护或胜负规则。
func build(team: int) -> bool:
	if team not in [0, 1]: return false
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/classic/base-catalog.json"))
	var entry: Dictionary = catalog.bases[team]
	var rgb: Array = entry.color
	model = Model.new()
	add_child(model)
	if not model.load_model("res://art/classic/" + entry.model, 0 if team == 0 else 6,
		Color8(int(rgb[0]), int(rgb[1]), int(rgb[2]))):
		model.free()
		model = null
		return false
	model.scale *= float(entry.model_scale)
	model.animation_tags = PackedStringArray(entry.animation_tags)
	model.play("Stand", true)
	model.advance(0)
	return true
