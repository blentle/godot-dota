extends SceneTree
## 用原始头像模型与受控相机轨道检查位移、目标、滚转和暂停，避免仅验证字段存在。

const CameraAnimation = preload("res://presentation/classic/portrait_camera.gd")
const Model = preload("res://presentation/classic/model_view.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func track(start: float, a: Array, b: Array) -> Dictionary:
	return {"LineType": 1, "GlobalSeqId": null,
		"Keys": [{"Frame": start, "Vector": a}, {"Frame": start+1000, "Vector": b}]}

func run() -> void:
	var model := Model.new()
	root.add_child(model)
	check(model.load_model("res://art/classic/units/human/jaina/jaina_portrait.json"), "必须使用原始头像骨骼模型")
	model.play("Portrait", true)
	var start: float = model.data.Sequences[model.sequence].Interval[0]
	model.data.Cameras = [{"Position": [100, 0, 40], "TargetPosition": [0, 0, 40],
		"FieldOfView": PI/4, "NearClip": 8, "FarClip": 1000,
		"Translation": track(start, [0, 0, 0], [32, 0, 0]),
		"TargetTranslation": track(start, [0, 0, 0], [0, 32, 0]),
		"Rotation": track(start, [0], [PI/2])}]
	var camera := Camera3D.new()
	root.add_child(camera)
	var animation := CameraAnimation.new()
	model.advance(0)
	animation.bind(model, camera)
	var original := camera.global_position
	var up := camera.global_basis.y
	model.advance(0.5)
	animation.advance()
	check(is_equal_approx(camera.global_position.distance_to(original), 0.4), "相机位移必须随模型单位缩放，半秒移动 0.4 Godot 单位")
	var direction: Vector3 = (model.global_basis * Vector3(-116, 16, 0)).normalized()
	check((-camera.global_basis.z).dot(direction) > 0.99999, "相机必须看向动画后的目标，不能只移动位置")
	check(is_equal_approx(absf(camera.global_basis.y.dot(up)), sqrt(0.5)), "相机滚转必须使用原始时间轨")
	check(is_equal_approx(camera.fov, 45) and is_equal_approx(camera.near, 0.2), "头像视野和裁剪面必须来自模型相机")
	# 未推进模型时钟时重复取景不应叠加滚转或位移。
	var pose := camera.global_transform
	animation.advance()
	check(camera.global_transform.is_equal_approx(pose), "重复更新不能累加相机滚转")
	model.data.Cameras = []
	animation.bind(model, camera)
	animation.advance()
	check(animation.source.is_empty() and camera.global_transform.is_equal_approx(pose), "新模型没有相机时不能沿用上一个英雄的相机轨道")
	model.queue_free()
	camera.queue_free()
	var portrait = load("res://ui/war3/scenes/retail_portrait.tscn").instantiate()
	root.add_child(portrait)
	portrait.set_process(false)
	portrait.set_character("jaina")
	portrait.paused = true
	var before: float = portrait.model.clock
	var frozen: Transform3D = portrait.get_node("Viewport/World/Camera").global_transform
	portrait._process(0.5)
	check(portrait.model.clock == before and portrait.get_node("Viewport/World/Camera").global_transform == frozen, "暂停必须同时冻结骨骼和头像相机")
	portrait.paused = false
	portrait._process(0.5)
	check(portrait.model.clock > before, "恢复后头像时间轨应继续推进")
	portrait.queue_free()
	await process_frame
	print("经典头像相机回归，失败数：", failures)
	quit(1 if failures else 0)
