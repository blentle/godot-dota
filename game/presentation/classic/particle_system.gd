extends Node3D
## 原始 ParticleEmitter2 调度：固定步长、可复用对象池及每模型硬上限，只读模型时间轨。

const State = preload("res://presentation/classic/particle_state.gd")
const Batch = preload("res://presentation/classic/particle_batch.gd")
const Tracks = preload("res://presentation/classic/animation_tracks.gd")
const CAPACITY := 512
const STEP := 1.0/60.0
var model: Node3D
var emitters: Array = []
var active: Array = []
var free: Array = []
var rng := RandomNumberGenerator.new()
var remainder := 0.0
var dropped := 0
var dropped_time := 0.0
var at_clock := 0.0
var at_global := 0.0

func bind(view: Node3D) -> void:
	reset()
	for emitter in emitters:
		remove_child(emitter.batch)
		emitter.batch.queue_free()
	emitters.clear()
	free.clear()
	model = view
	rng.seed = 683
	for entry in model.data.ParticleEmitters2:
		var batch := Batch.new()
		add_child(batch)
		batch.build(model, entry)
		emitters.append({"source": entry, "batch": batch, "credit": 0.0, "last": ""})
	if not emitters.is_empty():
		for index in range(CAPACITY): free.append(State.new())

func reset() -> void:
	for particle in active: free.append(particle)
	active.clear()
	for emitter in emitters:
		emitter.batch.particles.clear()
		emitter.credit = 0.0
		emitter.last = ""
	remainder = 0
	dropped = 0
	dropped_time = 0
	rng.seed = 683

func advance(delta: float) -> void:
	if emitters.is_empty() or delta <= 0: return
	# 超过两秒的单次跳时只处理有界窗口，防止后台恢复时无上限追帧。
	dropped_time += maxf(0, delta-2.0)
	remainder += minf(delta, 2.0)
	model.skeleton.force_update_all_bone_transforms()
	while remainder + 0.000001 >= STEP:
		remainder -= STEP
		at_clock = model.clock - remainder*1000
		at_global = model.global_clock - remainder*1000
		_step()

func _context(track: Variant) -> Vector2:
	var clip: Dictionary = model.data.Sequences[model.sequence]
	var interval := Vector2(clip.Interval[0], clip.Interval[1])
	if track is Dictionary and track.get("GlobalSeqId") != null:
		interval = Vector2(0, model.data.GlobalSequences[int(track.GlobalSeqId)])
	return interval

func _time(track: Variant) -> float:
	var interval := _context(track)
	if track is Dictionary and track.get("GlobalSeqId") != null:
		return fposmod(at_global, interval.y) if interval.y > 0 else 0.0
	var length := maxf(1, interval.y-interval.x)
	var clip: Dictionary = model.data.Sequences[model.sequence]
	return interval.x + (minf(at_clock, length) if clip.NonLooping else fposmod(at_clock, length))

func sample(track: Variant, fallback: float) -> float:
	return float(Tracks.sample(track, _time(track), fallback, _context(track)))

func _step() -> void:
	for index in range(active.size()-1, -1, -1):
		var particle: RefCounted = active[index]
		if not particle.step(STEP):
			emitters[particle.emitter].batch.particles.erase(particle)
			active.remove_at(index)
			free.append(particle)
	for index in range(emitters.size()):
		var emitter: Dictionary = emitters[index]
		var source: Dictionary = emitter.source
		if sample(source.get("Visibility"), 1) <= 0.01: continue
		var rate := maxf(0, sample(source.EmissionRate, 0))
		if source.Squirt:
			var key := _key(source.EmissionRate)
			if key != emitter.last:
				emitter.credit += rate
				emitter.last = key
		else: emitter.credit += rate * STEP
		var requested := int(emitter.credit)
		emitter.credit -= requested
		var accepted := mini(requested, free.size())
		dropped += requested-accepted
		for count in range(accepted): _spawn(index)

func _key(track: Variant) -> String:
	if not track is Dictionary: return str(model.action_serial)
	var key := -1.0
	var interval := _context(track)
	for entry in track.Keys:
		if entry.Frame >= interval.x and entry.Frame <= _time(track): key = entry.Frame
	var length := maxf(1, interval.y-interval.x)
	var time := at_global if track.get("GlobalSeqId") != null else at_clock
	var loops: bool = track.get("GlobalSeqId") != null or not model.data.Sequences[model.sequence].NonLooping
	var cycle := int(time/length) if loops else 0
	# 重播同一攻击也应再次喷发；全局喷发不能因切换动作而额外触发。
	var context: String = "g%s" % track.GlobalSeqId if track.get("GlobalSeqId") != null else "a%d" % model.action_serial
	return "%s:%d:%s" % [context, cycle, key]

func transform_for(source: Dictionary) -> Transform3D:
	return model.global_transform * model.skeleton.get_bone_global_pose(model.bone_ids[int(source.ObjectId)])

func _spawn(index: int) -> void:
	var emitter: Dictionary = emitters[index]
	var source: Dictionary = emitter.source
	if float(source.LifeSpan) <= 0: return
	var particle: RefCounted = free.pop_back()
	var transform := transform_for(source)
	var latitude := deg_to_rad(sample(source.Latitude, 0))
	var rotation := Basis(Vector3(0, 0, 1), PI/2) * Basis(Vector3.UP, rng.randf_range(-latitude, latitude))
	if not int(source.Flags) & 131072:
		rotation *= Basis(Vector3.RIGHT, rng.randf_range(-latitude, latitude))
	var speed := sample(source.Speed, 0) * (1+rng.randf_range(-sample(source.Variation, 0), sample(source.Variation, 0)))
	particle.emitter = index
	particle.age = 0
	particle.life = float(source.LifeSpan)
	particle.local_space = (int(source.Flags) & 524288) != 0
	particle.position = Vector3(rng.randf_range(-0.5, 0.5)*sample(source.Width, 0),
		rng.randf_range(-0.5, 0.5)*sample(source.Length, 0), 0)
	particle.velocity = rotation * Vector3(0, 0, speed)
	particle.size_scale = transform.basis.z.length()
	particle.gravity = sample(source.Gravity, 0)
	if not particle.local_space:
		particle.position = transform * particle.position
		particle.velocity = transform.basis * particle.velocity
		particle.gravity *= particle.size_scale
	particle.facing = atan2(particle.velocity.y, particle.velocity.x)-PI+PI/8
	active.append(particle)
	emitter.batch.particles.append(particle)

func _process(_delta: float) -> void:
	for emitter in emitters:
		emitter.batch.emitter_transform = transform_for(emitter.source)
		emitter.batch.draw(get_viewport().get_camera_3d())
