extends TextureRect
## 原始种族时钟：配置直接选择源模型；动画预览不代表权威昼夜状态。
const Model = preload("res://presentation/classic/model_view.gd")
const Art = preload("res://ui/war3/scripts/classic_art.gd")
const MODEL_PATH := "res://art/classic/ui/console/human/humanui-timeindicator.json"
const PATHS := {
	"human": MODEL_PATH,
	"nightelf": "res://art/classic/ui/console/nightelf/nightelfui-timeindicator.json",
	"undead": "res://art/classic/ui/console/undead/undeadui-timeindicator.json"}
var model: Node3D
var paused := false
var dynamic := false
var frame_race := "human"
var loaded_path := ""

func _ready() -> void:
	configure_race(frame_race)

func bind_model(path: String) -> bool:
	if is_instance_valid(model):
		$Viewport/World.remove_child(model)
		model.queue_free()
	model = null
	dynamic = false
	loaded_path = ""
	$Viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	texture = Art.texture("clock-%s.png" % frame_race)
	# 预先检查输入，失败时不留下半初始化模型或访问缺失序列。
	if not path in PATHS.values() or not FileAccess.file_exists(path): return false
	model = Model.new()
	$Viewport/World.add_child(model)
	if not model.load_model(path):
		$Viewport/World.remove_child(model)
		model.queue_free()
		model = null
		return false
	# 三种族原始网格范围一致，复用已验证的 XY 正交相机及千倍尺度。
	model.rotation = Vector3.ZERO
	model.scale = Vector3.ONE*1000
	dynamic = true
	loaded_path = path
	texture = $Viewport.get_texture()
	$Viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sample_sequence(0,0)
	return true

func sample_sequence(index: int, seconds: float) -> void:
	if not dynamic or not is_instance_valid(model): return
	if index < 0 or index >= model.data.Sequences.size(): return
	model.reset_effects()
	model.sequence = index
	model.clock = maxf(0, seconds)*1000
	model.global_clock = model.clock
	model.advance(0)

func advance(delta: float) -> void:
	if dynamic and not paused and is_instance_valid(model): model.advance(maxf(0,delta))

func configure_race(race: String) -> void:
	if not PATHS.has(race): return
	frame_race = race
	if dynamic and loaded_path == PATHS[race]: return
	bind_model(PATHS[race])

func _process(delta: float) -> void:
	advance(delta)
