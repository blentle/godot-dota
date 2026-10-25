extends TextureRect
## 原始时钟模型的独立表现视口；时间仅用于动画校对，不代表权威昼夜状态。
const Model = preload("res://presentation/classic/model_view.gd")
const Art = preload("res://ui/war3/scripts/classic_art.gd")
const MODEL_PATH := "res://art/classic/ui/console/human/humanui-timeindicator.json"
var model: Node3D
var paused := false
var dynamic := true
var frame_race := ""

func _ready() -> void:
	texture = $Viewport.get_texture()
	bind_model(MODEL_PATH)

func bind_model(path: String) -> bool:
	if is_instance_valid(model):
		$Viewport/World.remove_child(model)
		model.queue_free()
	model = Model.new()
	$Viewport/World.add_child(model)
	if not model.load_model(path): return false
	# 原始 UI 模型在 XY 平面，框范围 x=.337..465、y=.536..600。
	# 不沿用英雄坐标转换；放大千倍避免小尺度相机裁剪精度问题。
	model.rotation = Vector3.ZERO
	model.scale = Vector3.ONE*1000
	sample_sequence(0,0)
	if not frame_race.is_empty(): configure_race(frame_race)
	return true

func sample_sequence(index: int, seconds: float) -> void:
	if not is_instance_valid(model) or index < 0 or index >= model.data.Sequences.size(): return
	model.reset_effects()
	model.sequence = index
	model.clock = maxf(0, seconds)*1000
	model.global_clock = model.clock
	model.advance(0)

func advance(delta: float) -> void:
	if dynamic and not paused and is_instance_valid(model): model.advance(maxf(0,delta))

func configure_race(race: String) -> void:
	frame_race = race
	# 本轮仅验证近卫皮肤，其他种族保留原静态入口，不宣称已完成还原。
	dynamic = race == "nightelf"
	$Viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if dynamic else SubViewport.UPDATE_DISABLED
	if not dynamic:
		texture = Art.texture("clock-%s.png" % race)
		return
	texture = $Viewport.get_texture()
	for index in range(model.data.Geosets.size()):
		if int(model.data.Geosets[index].MaterialID) == 4:
			model.surfaces[index].material_override.albedo_texture = Art.texture("ui/console/nightelf/nightelfuitile-timeindicatorframe.png")

func _process(delta: float) -> void:
	advance(delta)
