extends SceneTree
## 原始奇美拉死亡碎片：资源、子步出生、世界轨迹、生命周期及对象池边界。

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
	check(model.load_model("res://art/classic/units/nightelf/chimaera/chimaera.json"), "必须能加载原始奇美拉")
	var system: Node3D = model.model_particles
	check(system.emitters.size() == 4, "奇美拉应保留四个旧式发射器")
	for emitter in system.emitters:
		check(FileAccess.file_exists(emitter.path), "缺少原始碎片模型："+emitter.path)
	model.play("Death", true)
	model.advance(0.45)
	check(not system.active.is_empty(), "一次推进应捕获原始死亡短窗口内的羽毛和骨骼")
	if not system.active.is_empty():
		var entry: Dictionary = system.active[0]
		check(entry.view.sequence == 0, "碎片应使用源模型第一段序列")
		check(entry.view.particles == null and entry.view.model_particles == null, "碎片不得递归创建发射器")
		check(entry.view.global_basis.get_scale().length() > 0.01, "碎片不得重复应用单位缩放而缩成不可见")
		var before: Vector3 = entry.view.global_position
		model.position += Vector3(100, 0, 0)
		check(entry.view.global_position.is_equal_approx(before), "抛出后应脱离父模型移动")
	var allocated: int = system.active.size()+system.pool.size()
	model.advance(2)
	model.advance(2)
	check(system.active.is_empty(), "原始寿命结束后必须回收碎片")
	check(system.pool.size() >= allocated, "回收不能丢失已分配对象")
	allocated = system.pool.size()
	model.play("Death", true)
	model.advance(0.45)
	check(system.active.size()+system.pool.size() == allocated, "相同死亡动作应复用既有模型池")
	system.reset()
	check(system.active.is_empty(), "重置应隐藏并回收全部活动碎片")
	for emitter in system.emitters:
		emitter.source.Visibility = 1
		emitter.source.EmissionRate = 100000
	model.advance(0.1)
	check(system.active.size()+system.pool.size() <= system.CAPACITY, "多个发射器共享容量上限")
	check(system.dropped > 0, "超出容量应计数并丢弃")
	model.advance(3)
	check(system.dropped_time > 0, "过长帧必须限制追赶时间")
	system.bind(model)
	check(system.active.is_empty() and system.pool.is_empty(), "重新绑定必须释放旧池")
	model.queue_free()
	await process_frame
	print("经典模型粒子回归，失败数：", failures)
	quit(1 if failures else 0)
