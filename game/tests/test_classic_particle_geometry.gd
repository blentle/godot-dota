extends SceneTree
## 检查原始粒子批次的顶点、图集、分段颜色和拖尾，防止计数通过但绘制位置错误。

const Model = preload("res://presentation/classic/model_view.gd")
const State = preload("res://presentation/classic/particle_state.gd")
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
	model.particles.set_process(false)
	var batch: MeshInstance3D = model.particles.emitters[0].batch
	var source: Dictionary = batch.source
	source.FrameFlags = 3
	source.Rows = 2
	source.Columns = 2
	source.Time = 0.5
	source.TailLength = 0.5
	source.Flags = 0
	source.SegmentColor = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
	source.Alpha = [255, 128, 0]
	source.ParticleScaling = [1, 2, 0]
	source.DecayUVAnim = [2, 4, 1]
	source.TailDecayUVAnim = [2, 4, 1]
	var particle := State.new()
	particle.position = Vector3(20, 30, 40)
	particle.velocity = Vector3(0, 0, 2)
	particle.age = 0.75
	particle.life = 1
	particle.size_scale = 0.025
	batch.particles.append(particle)
	var camera := Camera3D.new()
	root.add_child(camera)
	batch.draw(camera)
	check(batch.global_transform.is_equal_approx(Transform3D.IDENTITY), "世界空间批次不能再次继承模型缩放")
	check(batch.geometry.get_surface_count() == 1, "同一发射器应形成一个批次")
	var arrays: Array = batch.geometry.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	check(vertices.size() == 12, "头部和拖尾应各绘制两个三角形")
	var center: Vector3 = (vertices[0]+vertices[1]+vertices[2]+vertices[5])/4
	check(center.is_equal_approx(particle.position), "头部必须围绕原世界位置绘制")
	check(uv[0].is_equal_approx(Vector2(1, 0.5)), "衰减阶段应选择原图集第四格，不得按整图采样")
	check(particle.color(source).is_equal_approx(Color(0, 0.5, 0.5, 64.0/255)), "颜色和透明度必须按原始三阶段插值")
	# ImmediateMesh 顶点颜色打包为 RGBA8，允许一次 8 位量化误差。
	check(absf(colors[0].g-0.5) <= 1.0/255 and absf(colors[0].b-0.5) <= 1.0/255 and absf(colors[0].a-64.0/255) <= 1.0/255, "上传后的颜色偏差不能超过 8 位量化范围")
	check(is_equal_approx(vertices[7].z, 39), "拖尾长度必须由粒子速度与原始 TailLength 决定")
	source.ReplaceableId = 2
	batch.draw(camera)
	var team_uv: PackedVector2Array = batch.geometry.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	check(team_uv[0].is_equal_approx(Vector2(1, 0)), "独立队色纹理不能再次按组合图集切割")
	batch.particles.clear()
	batch.draw(camera)
	check(batch.geometry.get_surface_count() == 0, "粒子回收后必须清除上一帧几何")
	model.queue_free()
	camera.queue_free()
	await process_frame
	print("经典粒子绘制回归，失败数：", failures)
	quit(1 if failures else 0)
