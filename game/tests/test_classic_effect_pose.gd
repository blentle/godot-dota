extends SceneTree
## 子步取样必须匹配可见骨骼结果；一次较长推进也应保留原始挥砍轨迹。

const Model = preload("res://presentation/classic/model_view.gd")
const Pose = preload("res://presentation/classic/effect_pose.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	for path in ["units/human/heromountainking/heromountainking", "units/other/proudmoore/proudmoore"]:
		var model := Model.new()
		root.add_child(model)
		if not FileAccess.file_exists("res://art/classic/"+path+".json"):
			check(false, "缺少原始骨骼回归资源："+path)
			model.queue_free()
			continue
		model.load_model("res://art/classic/"+path+".json")
		model.play("Attack", true)
		model.advance(0.45)
		model.skeleton.force_update_all_bone_transforms()
		var pose := Pose.new()
		pose.begin(model, model.clock, model.global_clock)
		for index in range(model.data.Nodes.size()):
			var expected: Transform3D = model.global_transform * model.skeleton.get_bone_global_pose(index)
			check(pose.transform_for(int(model.data.Nodes[index].ObjectId)).is_equal_approx(expected), "子步骨骼应匹配当前可见姿态："+str(index))
		var before: Transform3D = model.skeleton.get_bone_global_pose(0)
		pose.begin(model, 100, 100)
		pose.transform_for(0)
		check(model.skeleton.get_bone_global_pose(0) == before, "离线子步取样不得改写可见 Skeleton")
		if not model.data.RibbonEmitters.is_empty():
			var strips := 0
			for emitter in model.ribbons.emitters:
				emitter.batch.draw()
				strips += emitter.batch.strips
			check(strips > 0, "一次推进 0.45 秒也必须保留真实挥砍轨迹，不能所有截面重叠")
		model.queue_free()
	await process_frame
	print("经典特效骨骼取样回归，失败数：", failures)
	quit(1 if failures else 0)
