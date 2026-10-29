extends TextureRect
## 原始动态头像：加载配套 portrait 模型，按模型携带的相机取景。

const Model = preload("res://presentation/classic/model_view.gd")
const Catalog = preload("res://presentation/classic/hero_catalog.gd")
const CameraAnimation = preload("res://presentation/classic/portrait_camera.gd")
var model: Node3D
var character := ""
var paused := false
var camera_animation := CameraAnimation.new()

func _ready() -> void:
	texture = $Viewport.get_texture()

func set_character(name: String) -> void:
	set_hero(Catalog.find("Hmbr" if name == "heromountainking" else "Hjai"))

func set_hero(hero: Dictionary) -> void:
	texture = $Viewport.get_texture()
	if character == hero.id: return
	camera_animation.clear()
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
	camera_animation.bind(model, $Viewport/World/Camera)

func _process(delta: float) -> void:
	if is_instance_valid(model) and not paused:
		model.advance(delta)
		camera_animation.advance()
