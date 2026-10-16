extends TextureRect
## 原始动态头像：加载配套 portrait 模型，按模型携带的相机取景。

const Model = preload("res://presentation/classic/model_view.gd")
const Catalog = preload("res://presentation/classic/hero_catalog.gd")
var model: Node3D
var character := ""
var paused := false

func _ready() -> void:
	texture = $Viewport.get_texture()

func set_character(name: String) -> void:
	set_hero(Catalog.find("Hmbr" if name == "heromountainking" else "Hjai"))

func set_hero(hero: Dictionary) -> void:
	texture = $Viewport.get_texture()
	if character == hero.id: return
	if is_instance_valid(model):
		$Viewport/World.remove_child(model)
		model.queue_free()
	character = hero.id
	model = Model.new()
	$Viewport/World.add_child(model)
	var path := Catalog.model_path(hero).replace(".json", "_portrait.json")
	# 某些原模型直接在本体携带头像相机，先用独立头像，再检查本体。
	if not FileAccess.file_exists(path): path = Catalog.model_path(hero)
	var color := Color8(int(hero.color[0]), int(hero.color[1]), int(hero.color[2]))
	if not model.load_model(path, 1, color): return
	model.animation_tags = PackedStringArray(hero.animation_tags)
	model.play("Portrait")
	model.advance(0)
	if model.data.Cameras.is_empty(): return
	var camera: Dictionary = model.data.Cameras[0]
	var view: Camera3D = $Viewport/World/Camera
	view.fov = rad_to_deg(float(camera.FieldOfView))
	view.near = float(camera.NearClip) * 0.025
	view.far = float(camera.FarClip) * 0.025
	view.global_position = model.to_global(Model.vector(camera.Position))
	view.look_at(model.to_global(Model.vector(camera.TargetPosition)), Vector3.UP)

func _process(delta: float) -> void:
	if is_instance_valid(model) and not paused: model.advance(delta)
