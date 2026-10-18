extends RefCounted
## 头像相机使用模型自己的位置、目标和滚转轨道，和骨骼共用同一动作时钟。

var model: Node3D
var camera: Camera3D
var source: Dictionary = {}

func clear() -> void:
	source = {}
	model = null
	camera = null

func bind(view: Node3D, target: Camera3D) -> void:
	clear()
	model = view
	camera = target
	if model.data.Cameras.is_empty(): return
	source = model.data.Cameras[0]
	camera.fov = rad_to_deg(float(source.FieldOfView))
	camera.near = maxf(0.001, float(source.NearClip) * model.scale.x)
	camera.far = maxf(camera.near + 1, float(source.FarClip) * model.scale.x)
	advance()

func advance() -> void:
	if source.is_empty() or not is_instance_valid(model) or not is_instance_valid(camera): return
	if model.sequence < 0: return
	var position: Vector3 = _vector(source.Position) + model.sample(source.get("Translation"), Vector3.ZERO)
	var target: Vector3 = _vector(source.TargetPosition) + model.sample(source.get("TargetTranslation"), Vector3.ZERO)
	camera.global_position = model.to_global(position)
	var destination: Vector3 = model.to_global(target)
	if camera.global_position.is_equal_approx(destination): return
	var up := Vector3.UP
	if (destination-camera.global_position).normalized().cross(up).length_squared() < 0.00001:
		up = Vector3.RIGHT
	camera.look_at(destination, up)
	var roll: Variant = model.sample(source.get("Rotation"), 0.0)
	if roll is Array: roll = roll[0]
	camera.rotate_object_local(Vector3.BACK, float(roll))

static func _vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])
