extends SceneTree
## 校验原始模型的多层材质、动画形态、骨骼与地图目录；不以加载成功冒充视觉验收。

const Model = preload("res://presentation/classic/model_view.gd")
const Catalog = preload("res://presentation/classic/hero_catalog.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	check(Catalog.entries().size() == 112, "酒馆英雄映射必须完整保留 112 项")
	var zeus := Catalog.find("Hmbr")
	check(zeus.animation_tags.has("alternate") and zeus.model_scale == 1.3, "宙斯外观必须使用地图 alternate 和缩放")
	check(str(zeus.icon).ends_with("btnavatar.blp"), "宙斯头像不能错误使用默认山丘图标")
	var model := Model.new()
	root.add_child(model)
	check(model.load_model(Catalog.model_path(zeus)), "原始经典模型必须能够构建骨骼与网格")
	check(model.skeleton.get_bone_count() == 103 and model.surfaces.size() == 8, "山丘原始骨骼和 Geoset 不能裁减")
	model.animation_tags = ["alternate"]
	for action in ["Stand", "Walk", "Attack", "Death"]:
		model.play(action, true)
		check(str(model.data.Sequences[model.sequence].Name).to_lower().contains("alternate"), "动作必须保留地图形态：" + action)
		model.advance(0.15)
	check(model.frame > model.data.Sequences[model.sequence].Interval[0], "动画时钟必须实际推进")
	model.play("Walk", true)
	model.advance(0)
	var poses: Array = []
	for index in range(model.skeleton.get_bone_count()): poses.append(model.skeleton.get_bone_pose(index))
	model.advance(0.2)
	var changed := false
	for index in range(poses.size()):
		if not poses[index].is_equal_approx(model.skeleton.get_bone_pose(index)): changed = true
	check(changed, "行走必须改变骨骼姿态，不能只有模型加载成功")
	var layered := false
	for index in model.materials.cache:
		var passes: Array = model.materials.cache[index]
		if passes.size() > 1:
			layered = true
			check(passes[0].next_pass == passes[1], "原模型的队色、普通和变身层必须按顺序链接")
	check(layered, "回归模型必须覆盖多层材质")
	model.queue_free()
	await process_frame
	print("经典模型与地图目录回归，失败数：", failures)
	quit(1 if failures else 0)
