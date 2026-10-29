extends SceneTree
## 复活/传送只切断表现轨迹：三类原始特效回收，正常移动与死亡不提前清除。

const View = preload("res://presentation/unit_view.gd")
const Unit = preload("res://simulation/combat/unit_state.gd")
const Continuity = preload("res://presentation/classic/effect_continuity.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func fill(view: Node3D, action: String) -> int:
	var model: Node3D = view.classic_model
	model.reset_effects()
	model.play(action, true)
	model.advance(0.45)
	var total: int = model.particles.active.size()+model.model_particles.active.size()
	var drawn := false
	for emitter in model.particles.emitters:
		emitter.batch.draw(root.get_camera_3d())
		drawn = drawn or emitter.batch.geometry.get_surface_count() > 0
	if not model.particles.active.is_empty(): check(drawn, "普通粒子应先绘制几何，再验证立即清除")
	for emitter in model.ribbons.emitters:
		emitter.batch.draw()
		total += emitter.batch.sections.size()
	return total

func cleared(model: Node3D) -> void:
	check(model.particles.active.is_empty(), "旧普通粒子必须回收")
	check(model.model_particles.active.is_empty(), "旧模型碎片必须回收")
	for entry in model.model_particles.pool:
		check(not entry.view.visible, "回收的旧模型碎片必须立即隐藏")
	for emitter in model.particles.emitters:
		check(emitter.batch.geometry.get_surface_count() == 0, "清理不能残留上一帧粒子几何")
	for emitter in model.ribbons.emitters:
		check(emitter.batch.sections.is_empty(), "旧飘带截面必须回收")
		check(emitter.batch.geometry.get_surface_count() == 0 and emitter.batch.strips == 0, "清理不能残留上一帧飘带几何")

func run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 8, 10)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var continuity := Continuity.new()
	check(not continuity.observe(Vector3(100, 0, 0), 1), "首次出现在远处不算传送")
	check(not continuity.observe(Vector3(112, 0, 0), 1), "位置阈值边界应保持连续")
	check(continuity.observe(Vector3(124.01, 0, 0), 1), "超过阈值应切断轨迹")
	check(continuity.observe(Vector3(124.01, 0, 0), 2), "原地复活也必须切断旧轨迹")
	check(not continuity.observe(Vector3(124.01, 0, 0), 2), "同一状态重复同步不能反复清理")
	for path in ["units/creeps/heroflamelord/heroflamelord", "units/other/proudmoore/proudmoore", "units/nightelf/chimaera/chimaera"]:
		var view := View.new()
		view.visual_resource = "res://art/classic/"+path+".json"
		root.add_child(view)
		view.build(Color.WHITE)
		var state := Unit.new()
		view.sync(state, true, 0, state.position)
		var action := "Death" if "chimaera" in path else "Attack"
		check(fill(view, action) > 0, "原始模型必须生成待清理轨迹："+path)
		var model: Node3D = view.classic_model
		var count := fill_count(model)
		var before: Array = [state.hp, state.mana, state.life_id, state.position]
		view.sync(state, true, 0, state.position)
		check(fill_count(model) == count, "零推进不应清理活动特效")
		check(before == [state.hp, state.mana, state.life_id, state.position], "表现同步不得改写规则")
		state.position += Vector3(1, 0, 0)
		view.sync(state, true, 0, state.position)
		state.hp = 0
		view.sync(state, true, 0, state.position)
		check(fill_count(model) > 0, "正常移动和同代次死亡不得清除原始死亡碎片或攻击尾迹")
		state.position += Vector3(20, 0, 0)
		view.sync(state, true, 0, state.position)
		cleared(model)
		check(fill(view, action) > 0, "清理后仍应能生成新特效")
		state.life_id += 1
		state.hp = state.max_hp
		view.sync(state, true, 0, state.position)
		cleared(model)
		view.queue_free()
	camera.queue_free()
	await process_frame
	print("经典特效连续性回归，失败数：", failures)
	quit(1 if failures else 0)

func fill_count(model: Node3D) -> int:
	var total: int = model.particles.active.size()+model.model_particles.active.size()
	for emitter in model.ribbons.emitters: total += emitter.batch.sections.size()
	return total
