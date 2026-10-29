extends Node3D
## 旧式 ParticleEmitter：抛出原始独立网格，以有界对象池保存世界空间轨迹。

const Tracks = preload("res://presentation/classic/effect_tracks.gd")
const Pose = preload("res://presentation/classic/effect_pose.gd")
const STEP := 1.0/60
const CAPACITY := 64
var model: Node3D
var emitters: Array = []
var active: Array = []
var pool: Array = []
var remainder := 0.0
var dropped := 0
var dropped_time := 0.0
var at_clock := 0.0
var at_global := 0.0
var pose := Pose.new()
var rng := RandomNumberGenerator.new()

func bind(view: Node3D) -> void:
	reset()
	for entry in pool:
		remove_child(entry.view)
		entry.view.queue_free()
	pool.clear()
	emitters.clear()
	model = view
	for source in model.data.get("ParticleEmitters", []):
		var path := str(source.Path).replace("\\", "/").to_lower().trim_suffix(".mdl").trim_suffix(".mdx")
		emitters.append({"source": source, "path": "res://art/classic/"+path+".json", "credit": 0.0})

func reset() -> void:
	for entry in active:
		entry.view.hide()
		pool.append(entry)
	active.clear()
	for emitter in emitters: emitter.credit = 0.0
	remainder = 0
	dropped = 0
	dropped_time = 0
	rng.seed = 683

func advance(delta: float) -> void:
	if emitters.is_empty() or delta <= 0: return
	dropped_time += maxf(0, delta-2)
	remainder += minf(delta, 2)
	while remainder+0.000001 >= STEP:
		remainder -= STEP
		at_clock = model.clock-remainder*1000
		at_global = model.global_clock-remainder*1000
		pose.begin(model, at_clock, at_global)
		_step()

func _sample(value: Variant, fallback: float) -> float:
	return float(Tracks.sample(model, value, fallback, at_clock, at_global))

func _step() -> void:
	# 原版碎片离开发射节点后保留世界轨迹；寿命结束隐藏并归还池。
	for index in range(active.size()-1, -1, -1):
		var entry: Dictionary = active[index]
		entry.age += STEP
		if entry.age+0.000001 >= entry.life:
			entry.view.hide()
			active.remove_at(index)
			pool.append(entry)
			continue
		entry.velocity += Vector3.DOWN*entry.gravity*STEP
		entry.view.global_position += entry.velocity*STEP
		entry.view.advance(STEP)
	for emitter in emitters:
		var source: Dictionary = emitter.source
		if _sample(source.get("Visibility"), 1) <= 0.01: continue
		emitter.credit += maxf(0, _sample(source.EmissionRate, 0))*STEP
		var count := int(emitter.credit)
		emitter.credit -= count
		for index in range(mini(count, CAPACITY)): _spawn(emitter)
		dropped += maxi(0, count-CAPACITY)

func _acquire(path: String) -> Dictionary:
	for index in range(pool.size()):
		if pool[index].path == path:
			var entry: Dictionary = pool[index]
			pool.remove_at(index)
			return entry
	if active.size()+pool.size() >= CAPACITY: return {}
	# 子模型不递归创建发射器，避免恶意引用环；本次原始碎片均无子发射器。
	var view = load("res://presentation/classic/model_view.gd").new()
	add_child(view)
	if not view.load_model(path, model.materials.team, model.materials.tint, false):
		remove_child(view)
		view.queue_free()
		return {}
	view.top_level = true
	return {"view": view, "path": path}

func _spawn(emitter: Dictionary) -> void:
	var source: Dictionary = emitter.source
	var life := _sample(source.LifeSpan, 0)
	if life <= 0: return
	var entry := _acquire(emitter.path)
	if entry.is_empty():
		dropped += 1
		return
	var transform: Transform3D = pose.transform_for(int(source.ObjectId))
	var latitude := _sample(source.Latitude, 0)
	var direction := Basis(Vector3.FORWARD, rng.randf_range(-PI, PI))*Basis(Vector3.UP, rng.randf_range(-latitude, latitude))*Vector3(0, 0, 1)
	entry.velocity = transform.basis*direction*_sample(source.InitVelocity, 0)
	entry.gravity = _sample(source.Gravity, 0)*transform.basis.get_scale().z
	entry.life = life
	entry.age = 0.0
	# 发射节点已含原模型到 Godot 的转换；替换子模型变换，不能再次乘 0.025。
	entry.view.global_transform = Transform3D(transform.basis*Basis(Vector3(0, 0, 1), rng.randf_range(0, TAU)), transform.origin)
	entry.view.sequence = 0 if not entry.view.data.Sequences.is_empty() else -1
	entry.view.clock = 0
	entry.view.global_clock = 0
	entry.view.advance(0)
	entry.view.show()
	active.append(entry)
