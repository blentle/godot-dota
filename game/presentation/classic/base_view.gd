extends "res://presentation/classic/tower_view.gd"
## 地图基地原始外观：复用建筑生命周期，不改写训练基地保护或胜负规则。
func build(team: int) -> bool:
	if team not in [0, 1]: return false
	var path := "war3mapimported/final_export.json" if team == 0 else "doodads/cinematic/lichking/lichking.json"
	model = Model.new()
	add_child(model)
	if not model.load_model("res://art/classic/" + path, 0 if team == 0 else 6):
		model.free()
		model = null
		return false
	model.scale *= 1.2 if team == 0 else 1.0
	model.play("Stand", true)
	model.advance(0)
	return true
