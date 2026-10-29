extends SceneTree
## 固定时间推进原模型骨骼上的受控发射器，验证数量守恒、喷发去重及空间语义。

const Model = preload("res://presentation/classic/model_view.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func emitter() -> Dictionary:
	return {"ObjectId": 0, "Flags": 0, "Speed": 0, "Variation": 0,
		"Latitude": 0, "Gravity": 0, "LifeSpan": 2.0, "EmissionRate": 20.0,
		"Width": 0, "Length": 0, "FilterMode": 0, "Rows": 2, "Columns": 2,
		"FrameFlags": 1, "TailLength": 1, "Time": 0.5,
		"SegmentColor": [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
		"Alpha": [255, 128, 0], "ParticleScaling": [1, 2, 0],
		"LifeSpanUVAnim": [0, 2, 1], "DecayUVAnim": [2, 4, 1],
		"TailUVAnim": [0, 2, 1], "TailDecayUVAnim": [2, 4, 1],
		"TextureID": 0, "ReplaceableId": 0, "Squirt": false,
		"PriorityPlane": 0, "Visibility": 1.0}

func subject(source: Dictionary) -> Node3D:
	var model := Model.new()
	root.add_child(model)
	model.load_model("res://art/classic/units/human/jaina/jaina.json")
	model.data.Sequences = [{"Name": "Stand", "Interval": [0, 5000], "NonLooping": false}]
	model.sequence = 0
	model.clock = 0
	model.global_clock = 0
	model.data.ParticleEmitters2 = [source]
	model.particles.bind(model)
	return model

func run() -> void:
	var source := emitter()
	var model := subject(source)
	model.advance(0.5)
	check(model.particles.active.size() == 10, "20 粒子/秒连续发射半秒必须为 10 个")
	var first: RefCounted = model.particles.active[0]
	var original: Vector3 = first.position
	model.position += Vector3(10, 0, 0)
	model.advance(0.5)
	check(model.particles.active.size() == 20, "分次推进不能丢失发射余量")
	check(first.position == original, "世界空间旧粒子不能被移动后的英雄拖走")
	source.Visibility = 0
	model.advance(2)
	check(model.particles.active.is_empty() and model.particles.free.size() == 512, "隐藏停止发射，但存量仍应老化并全部归还池")
	model.particles.reset()
	model.clock = 0
	source.Visibility = 1
	source.Flags = 524288
	model.advance(0.1)
	var local: RefCounted = model.particles.active[0]
	var before: Transform3D = model.particles.transform_for(source)
	model.position += Vector3(10, 0, 0)
	var after: Transform3D = model.particles.transform_for(source)
	check(local.local_space and (after*local.position-before*local.position).is_equal_approx(Vector3(10, 0, 0)), "ModelSpace 粒子应跟随源节点移动")
	var count: int = model.particles.active.size()
	var age: float = local.age
	model.advance(0)
	check(model.particles.active.size() == count and local.age == age, "零时间更新不得发射或老化粒子")

	# Squirt 只在关键帧切换时发射一次，不能每一帧重复喷发。
	model.particles.reset()
	model.clock = 0
	model.global_clock = 0
	source.Squirt = true
	source.EmissionRate = {"LineType": 0, "GlobalSeqId": null, "Keys": [
		{"Frame": 0, "Vector": [5]}, {"Frame": 1000, "Vector": [0]},
		{"Frame": 1500, "Vector": [3]}]}
	model.advance(0.5)
	check(model.particles.active.size() == 5, "一次性喷发不能按帧重复")
	model.advance(1.1)
	check(model.particles.active.size() == 8, "后续喷发关键帧应增加三个粒子")
	model.play("Stand", true)
	model.advance(1.0/60)
	check(model.particles.active.size() == 13, "显式重播同一动作必须重新触发喷发")
	model.particles.reset()
	model.global_clock = 0
	model.clock = 0
	var global_id: int = model.data.GlobalSequences.size()
	model.data.GlobalSequences.append(2000)
	model.data.Sequences[0].NonLooping = true
	source.EmissionRate = {"LineType": 0, "GlobalSeqId": global_id, "Keys": [
		{"Frame": 0, "Vector": [5]}, {"Frame": 1000, "Vector": [0]}]}
	model.advance(0.2)
	model.play("Stand", true)
	model.advance(0.2)
	check(model.particles.active.size() == 5, "重播动作不能额外触发全局喷发")
	model.advance(2)
	check(model.particles.active.size() == 5, "非循环动作中的全局喷发仍应随自身周期循环")
	model.particles.reset()
	source.Squirt = false
	source.EmissionRate = 1000000
	source.LifeSpan = 100
	model.advance(0.1)
	check(model.particles.active.size() == 512 and model.particles.dropped > 0, "超高发射率必须受模型粒子池上限约束")
	model.advance(10)
	check(model.particles.active.size() == 512 and is_equal_approx(model.particles.dropped_time, 8), "长跳时追帧必须有界并记录未处理时间")
	model.queue_free()
	await process_frame
	print("经典粒子生命周期回归，失败数：", failures)
	quit(1 if failures else 0)
