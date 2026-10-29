extends RefCounted
## 几何特效子步骨骼取样：独立计算原始局部变换，不临时改写可见 Skeleton。

const Tracks = preload("res://presentation/classic/effect_tracks.gd")
var model: Node3D
var clock := 0.0
var global_time := 0.0
var cache: Dictionary = {}

func begin(view: Node3D, at: float, global_at: float) -> void:
	model = view
	clock = at
	global_time = global_at
	cache.clear()

func transform_for(object_id: int) -> Transform3D:
	return model.global_transform * _bone(model.bone_ids[object_id])

func _bone(index: int) -> Transform3D:
	if cache.has(index): return cache[index]
	var source: Dictionary = model.data.Nodes[index]
	var rest: Transform3D = model.skeleton.get_bone_rest(index)
	var position: Vector3 = Tracks.sample(model, source.get("Translation"), Vector3.ZERO, clock, global_time)
	var rotation: Quaternion = Tracks.sample(model, source.get("Rotation"), Quaternion.IDENTITY, clock, global_time, true)
	var scale: Vector3 = Tracks.sample(model, source.get("Scaling"), Vector3.ONE, clock, global_time)
	var pose := Transform3D(Basis(rotation) * Basis.from_scale(scale), rest.origin+position)
	var parent: int = model.skeleton.get_bone_parent(index)
	if parent >= 0: pose = _bone(parent) * pose
	cache[index] = pose
	return pose
