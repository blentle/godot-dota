extends SceneTree
## 原始骨骼上的受控飘带：验证高度轴、世界空间截面、断带、图集、暂停及容量守恒。

const Model = preload("res://presentation/classic/model_view.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var model := Model.new()
	root.add_child(model)
	model.load_model("res://art/classic/units/human/jaina/jaina.json")
	model.ribbons.set_process(false)
	# 固定根骨骼，便于单独验证世界空间运动；真实动作轨迹另行测试。
	for field in ["Translation", "Rotation", "Scaling"]: model.data.Nodes[0][field] = null
	var source := {"ObjectId": 0, "MaterialID": 0, "HeightAbove": 12, "HeightBelow": 8,
		"Color": [1, 0.5, 0.25], "Alpha": 0.25, "LifeSpan": 2, "TextureSlot": 3,
		"EmissionRate": 20, "Rows": 2, "Columns": 2, "Gravity": 0, "Visibility": 1}
	model.data.RibbonEmitters = [source]
	model.ribbons.bind(model)
	var emitter: Dictionary = model.ribbons.emitters[0]
	var batch: MeshInstance3D = emitter.batch
	model.advance(0.5)
	check(batch.sections.size() == 10 and emitter.pool.size() == 118, "半秒必须生成十个截面并从固定池取得")
	var first: Vector3 = batch.sections[0].above
	model.position += Vector3(1, 0, 0)
	model.advance(0.05)
	check(batch.sections[0].above == first, "已发射截面必须留在世界空间")
	var section: Dictionary = batch.sections[-1]
	var expected: Vector3 = model.global_basis * model.skeleton.get_bone_global_pose(model.bone_ids[0]).basis * Vector3(0, 20, 0)
	check((section.above-section.below).is_equal_approx(expected), "原始 HeightAbove/Below 必须沿模型 Y 轴并正确缩放")
	batch.draw()
	check(batch.strips == 1, "同一位置重复截面不能提交退化三角形")
	check(batch.global_transform.is_equal_approx(Transform3D.IDENTITY), "世界空间飘带不能再次继承模型变换")
	var arrays: Array = batch.geometry.surface_get_arrays(0)
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	check(uv.size() == 6 and is_equal_approx(uv[0].y, 0.5) and is_equal_approx(uv[1].y, 1), "TextureSlot=3 必须使用二乘二图集的右下格")
	var material: StandardMaterial3D = batch.material_override
	check(material.albedo_color.is_equal_approx(Color(1, 0.5, 0.25, 0.25)), "飘带必须保留原始颜色和透明度")
	check(model.materials.instances.size() == model.surfaces.size(), "飘带材质不得混入 Geoset 更新列表")
	var count: int = batch.sections.size()
	var age: float = batch.sections[0].age
	model.advance(0)
	check(batch.sections.size() == count and batch.sections[0].age == age, "零时间推进不能新增或老化截面")

	# 停止后恢复必须新开一条轨迹，不能连到另一个位置的旧截面。
	source.Visibility = 0
	model.advance(0.05)
	model.position += Vector3(10, 0, 0)
	source.Visibility = 1
	model.advance(0.05)
	batch.draw()
	check(batch.strips == 1, "重新发射不能跨隐藏区间连接旧轨迹")
	source.Visibility = 0
	model.advance(2)
	batch.draw()
	check(batch.sections.is_empty() and emitter.pool.size() == 128, "停止发射后存量应全部回收")
	check(batch.geometry.get_surface_count() == 0, "回收后必须移除旧几何")
	model.ribbons.reset()
	source.Visibility = 1
	source.LifeSpan = 100
	source.EmissionRate = 1000000
	model.advance(0.1)
	check(batch.sections.size() == 128 and model.ribbons.dropped > 0, "超高发射率必须受截面池上限约束")
	model.advance(10)
	check(batch.sections.size() == 128 and is_equal_approx(model.ribbons.dropped_time, 8), "长跳时不能无界追帧")
	model.ribbons.bind(model)
	check(model.ribbons.emitters.size() == 1 and model.ribbons.emitters[0].pool.size() == 128, "重复绑定不能累加旧批次或池")
	model.queue_free()
	await process_frame
	print("经典飘带回归，失败数：", failures)
	quit(1 if failures else 0)
