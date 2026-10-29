extends Node3D
## 原始飘带生命周期：固定子步、截面池和有界采样，不修改游戏规则。

const Batch = preload("res://presentation/classic/ribbon_batch.gd")
const Tracks = preload("res://presentation/classic/effect_tracks.gd")
const Pose = preload("res://presentation/classic/effect_pose.gd")
const STEP := 1.0/60
const CAPACITY := 128
var model: Node3D
var emitters: Array = []
var remainder := 0.0
var dropped := 0
var dropped_time := 0.0
var at_clock := 0.0
var at_global := 0.0
var pose := Pose.new()

func bind(view: Node3D) -> void:
	reset()
	for emitter in emitters:
		remove_child(emitter.batch)
		emitter.batch.queue_free()
	emitters.clear()
	model = view
	for source in model.data.RibbonEmitters:
		var batch := Batch.new()
		add_child(batch)
		batch.build(model, source)
		var pool: Array = []
		for index in range(CAPACITY): pool.append({"above": Vector3.ZERO, "below": Vector3.ZERO,
			"age": 0.0, "chain": 0, "speed": 0.0})
		emitters.append({"source": source, "batch": batch, "pool": pool,
			"credit": 0.0, "chain": 0, "visible": false})

func reset() -> void:
	for emitter in emitters:
		emitter.pool.append_array(emitter.batch.sections)
		emitter.batch.sections.clear()
		emitter.batch.draw()
		emitter.credit = 0.0
		emitter.chain += 1
		emitter.visible = false
	remainder = 0
	dropped = 0
	dropped_time = 0

func advance(delta: float) -> void:
	if emitters.is_empty() or delta <= 0: return
	dropped_time += maxf(0, delta-2)
	remainder += minf(delta, 2)
	model.skeleton.force_update_all_bone_transforms()
	while remainder + 0.000001 >= STEP:
		remainder -= STEP
		at_clock = model.clock-remainder*1000
		at_global = model.global_clock-remainder*1000
		pose.begin(model, at_clock, at_global)
		for emitter in emitters: _step(emitter)

func _sample(value: Variant, fallback: Variant) -> Variant:
	return Tracks.sample(model, value, fallback, at_clock, at_global)

func _step(emitter: Dictionary) -> void:
	var source: Dictionary = emitter.source
	var sections: Array = emitter.batch.sections
	for index in range(sections.size()-1, -1, -1):
		var section: Dictionary = sections[index]
		section.age += STEP
		section.speed += float(source.Gravity)*STEP*model.scale.x
		var fall: Vector3 = Vector3.DOWN * section.speed*STEP
		section.above += fall
		section.below += fall
		if section.age + 0.000001 >= float(source.LifeSpan):
			sections.remove_at(index)
			emitter.pool.append(section)
	var visible: bool = float(_sample(source.get("Visibility"), 1)) > 0.01 and float(_sample(source.Alpha, 1)) > 0
	if visible != emitter.visible:
		emitter.chain += 1
		emitter.visible = visible
	if not visible: return
	emitter.credit += maxf(0, float(source.EmissionRate))*STEP
	var count := int(emitter.credit)
	emitter.credit -= count
	for index in range(mini(count, CAPACITY)):
		if emitter.pool.is_empty():
			dropped += 1
			continue
		_spawn(emitter)
	dropped += maxi(0, count-CAPACITY)

func _spawn(emitter: Dictionary) -> void:
	var source: Dictionary = emitter.source
	if float(source.LifeSpan) <= 0: return
	var transform: Transform3D = pose.transform_for(int(source.ObjectId))
	var section: Dictionary = emitter.pool.pop_back()
	section.above = transform * Vector3(0, float(_sample(source.HeightAbove, 0)), 0)
	section.below = transform * Vector3(0, -float(_sample(source.HeightBelow, 0)), 0)
	section.age = 0.0
	section.speed = 0.0
	section.chain = emitter.chain
	emitter.batch.sections.append(section)

func _process(_delta: float) -> void:
	for emitter in emitters: emitter.batch.draw()
