extends "res://tests/test_classic_particles.gd"
## 世界粒子出生位置应取出生时刻的骨骼；不同帧切分不能改变同一动画轨迹。

func moving_subject(global_track := false, local_space := false) -> Node3D:
	var source := emitter()
	source.Flags = 524288 if local_space else 0
	var model := subject(source)
	var node: Dictionary = model.data.Nodes[model.bone_ids[0]]
	node.Parent = null
	node.Rotation = null
	node.Scaling = null
	var global_id: Variant = null
	if global_track:
		global_id = model.data.GlobalSequences.size()
		model.data.GlobalSequences.append(1000)
	node.Translation = {"LineType": 1, "GlobalSeqId": global_id, "Keys": [
		{"Frame": 0, "Vector": [0, 0, 0]}, {"Frame": 1000, "Vector": [600, 0, 0]}]}
	return model

func run() -> void:
	for global_track in [false, true]:
		var whole := moving_subject(global_track)
		var split := moving_subject(global_track)
		whole.advance(0.5)
		for index in range(30): split.advance(1.0/60)
		check(whole.particles.active.size() == 10, "半秒应生成十个受控粒子")
		check(split.particles.active.size() == whole.particles.active.size(), "帧切分不能改变发射数量")
		var particles: Array = whole.particles.active
		if particles.size() == 10 and split.particles.active.size() == 10:
			# 发射率 20 Hz，首个在 50ms，末个在 500ms；位移应为 270 原始单位。
			var distance: float = particles[0].position.distance_to(particles[9].position)
			check(is_equal_approx(distance, 270*0.025), "长帧中的粒子必须沿原始骨骼轨迹分布，不能全部堆在终点")
			for index in range(10):
				check(particles[index].position.is_equal_approx(split.particles.active[index].position), "整帧与分帧的出生位置必须一致")
				check(is_equal_approx(particles[index].age, split.particles.active[index].age), "整帧与分帧的存量年龄必须一致")
		whole.skeleton.force_update_all_bone_transforms()
		var before: Transform3D = whole.skeleton.get_bone_global_pose(whole.bone_ids[0])
		whole.particles.pose.begin(whole, 50, 50)
		whole.particles.pose.transform_for(0)
		check(whole.skeleton.get_bone_global_pose(whole.bone_ids[0]) == before, "粒子子步不得改写可见骨骼")
		whole.queue_free()
		split.queue_free()
	var local := moving_subject(false, true)
	local.advance(0.5)
	for particle in local.particles.active:
		check(particle.local_space and particle.position == Vector3.ZERO, "ModelSpace 粒子仍保留局部坐标，不得烘焙出生世界位置")
	local.queue_free()
	# 真实英雄的喷发、多个发射器和带父骨骼轨道也必须与帧切分无关。
	for path in ["units/creeps/heroflamelord/heroflamelord", "units/creeps/seaelemental/seaelemental"]:
		var whole := Model.new()
		var split := Model.new()
		root.add_child(whole)
		root.add_child(split)
		check(whole.load_model("res://art/classic/"+path+".json"), "必须加载原始英雄："+path)
		check(split.load_model("res://art/classic/"+path+".json"), "必须加载分帧对照英雄："+path)
		whole.play("Attack", true)
		split.play("Attack", true)
		whole.advance(0.45)
		for index in range(27): split.advance(1.0/60)
		check(not whole.particles.active.is_empty(), "真实英雄必须产生粒子，不能空比较通过："+path)
		check(whole.particles.active.size() == split.particles.active.size(), "真实英雄分帧发射数量不一致："+path)
		for index in range(mini(whole.particles.active.size(), split.particles.active.size())):
			var a: RefCounted = whole.particles.active[index]
			var b: RefCounted = split.particles.active[index]
			check(a.position.is_equal_approx(b.position), "真实英雄分帧粒子轨迹不一致："+path)
			check(a.velocity.is_equal_approx(b.velocity), "真实英雄分帧初速度不一致："+path)
		whole.queue_free()
		split.queue_free()
	await process_frame
	print("经典粒子子步骨骼回归，失败数：", failures)
	quit(1 if failures else 0)
