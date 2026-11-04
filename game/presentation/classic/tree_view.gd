extends Node3D
## 原始树木静态表现；训练场树种分区和缩放不是原版地图放置。
const Model = preload("res://presentation/classic/model_view.gd")
var model: Node3D
func build(north: bool, variation: int, height: float) -> bool:
	var family := "northrendtree" if north else "ashentree"
	var count := 10 if north else 5
	var texture := "replaceabletextures/northrendtree/northtree.png" if north else "replaceabletextures/ashenvaletree/ashentree.png"
	model = Model.new()
	add_child(model)
	# ATtr 在固定地图对象覆盖中为 190 灰色乘色；NTtw 沿用基础白色。
	if not model.load_model("res://art/classic/doodads/terrain/%s/%s%d.json" % [family, family, posmod(variation, count)],
		1, Color.WHITE if north else Color8(190, 190, 190), false, {34 if north else 32: texture}):
		model.free()
		model = null
		return false
	model.scale *= height / 5.0
	model.play("Stand")
	model.advance(0)
	return true
