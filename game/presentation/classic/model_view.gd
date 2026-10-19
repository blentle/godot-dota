extends Node3D
## 原始经典模型视图：骨骼、矩阵组、动作序列、全局动画及 Geoset 可见性。

const Tracks = preload("res://presentation/classic/animation_tracks.gd")
const Materials = preload("res://presentation/classic/model_materials.gd")
const Meshes = preload("res://presentation/classic/model_meshes.gd")
const MaterialAnimation = preload("res://presentation/classic/material_animation.gd")
const Particles = preload("res://presentation/classic/particle_system.gd")
var data: Dictionary
var skeleton := Skeleton3D.new()
var materials := Materials.new()
var bone_ids: Dictionary = {}
var surfaces: Array[MeshInstance3D] = []
var sequence := -1
var action_serial := 0
var clock := 0.0
var global_clock := 0.0
var frame := 0.0
var animation_tags: PackedStringArray = []
var material_animation := MaterialAnimation.new()
var particles: Node3D

func load_model(path: String, team := 1, tint := Color.WHITE) -> bool:
	if not FileAccess.file_exists(path):
		push_error("未找到经典原始模型：" + path)
		return false
	data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data.get("Version") != 800:
		push_error("拒绝非经典格式模型")
		return false
	materials.model = data
	materials.team = team
	materials.tint = tint
	skeleton.name = "Skeleton"
	add_child(skeleton)
	for node in data.Nodes:
		var index := skeleton.get_bone_count()
		bone_ids[int(node.ObjectId)] = index
		skeleton.add_bone(str(node.Name) + "_" + str(node.ObjectId))
	for node in data.Nodes:
		var index: int = bone_ids[int(node.ObjectId)]
		var pivot := vector(node.PivotPoint)
		if node.Parent != null and bone_ids.has(int(node.Parent)):
			var parent: int = bone_ids[int(node.Parent)]
			skeleton.set_bone_parent(index, parent)
			pivot -= vector(data.Nodes[parent].PivotPoint)
		skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, pivot))
	skeleton.reset_bone_poses()
	var skin := Skin.new()
	for node in data.Nodes:
		skin.add_bind(bone_ids[int(node.ObjectId)], Transform3D(Basis.IDENTITY, -vector(node.PivotPoint)))
	for geoset in data.Geosets:
		var surface: MeshInstance3D = Meshes.create(geoset, bone_ids, skin, materials.material(int(geoset.MaterialID)))
		add_child(surface)
		surfaces.append(surface)
	material_animation.bind(self)
	# 原模型坐标 Z 向上、X 向前，转换为 Godot 的 Y 向上、-Z 向前。
	rotation_degrees = Vector3(-90, 90, 0)
	scale = Vector3.ONE * 0.025
	particles = Particles.new()
	add_child(particles)
	particles.bind(self)
	play("Stand")
	advance(0)
	return true

static func vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

func play(prefix: String, restart := false) -> void:
	# 地图 animProps 可位于动作名称首尾；宙斯固定使用 alternate，而非默认山丘形态。
	var best := -1
	var best_score := -1000
	for index in range(data.get("Sequences", []).size()):
		var words := str(data.Sequences[index].Name).to_lower().replace("-", " ").split(" ", false)
		if not prefix.to_lower() in words: continue
		var score := 0
		for tag in ["alternate", "upgrade", "swim", "defend"]:
			if tag in words:
				score += 10 if tag in animation_tags else -100
			elif tag in animation_tags:
				score -= 20
		if score > best_score:
			best_score = score
			best = index
	if best >= 0 and (sequence != best or restart):
		sequence = best
		clock = 0
		action_serial += 1

func sample(track: Variant, fallback: Variant, quaternion := false) -> Variant:
	if not track is Dictionary: return fallback if track == null else track
	var interval := Vector2(data.Sequences[sequence].Interval[0], data.Sequences[sequence].Interval[1])
	var at := frame
	if track.get("GlobalSeqId") != null:
		var duration := float(data.GlobalSequences[int(track.GlobalSeqId)])
		interval = Vector2(0, duration)
		at = fmod(global_clock, duration) if duration > 0 else 0.0
	return Tracks.sample(track, at, fallback, interval, quaternion)

func advance(delta: float) -> void:
	if sequence < 0: return
	clock += delta * 1000
	global_clock += delta * 1000
	var clip: Dictionary = data.Sequences[sequence]
	var length: float = maxf(1, clip.Interval[1] - clip.Interval[0])
	frame = clip.Interval[0] + (minf(clock, length) if clip.NonLooping else fmod(clock, length))
	for node in data.Nodes:
		var index: int = bone_ids[int(node.ObjectId)]
		var rest := skeleton.get_bone_rest(index).origin
		skeleton.set_bone_pose_position(index, rest + sample(node.get("Translation"), Vector3.ZERO))
		skeleton.set_bone_pose_rotation(index, sample(node.get("Rotation"), Quaternion.IDENTITY, true))
		skeleton.set_bone_pose_scale(index, sample(node.get("Scaling"), Vector3.ONE))
	material_animation.advance()
	if particles != null: particles.advance(delta)
