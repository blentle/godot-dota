extends SceneTree
## 检查真实滚动模型及多 Geoset 共材质的边界，确保表现更新不串色、不丢失淡出。

const Model = preload("res://presentation/classic/model_view.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var revenant := Model.new()
	root.add_child(revenant)
	check(revenant.load_model("res://art/classic/units/creeps/revenant/revenant.json"), "电魂原始模型必须可读")
	var scrolling: StandardMaterial3D = revenant.surfaces[0].material_override
	var texture: Texture2D = scrolling.albedo_texture
	revenant.advance(0.5)
	check(is_equal_approx(scrolling.uv1_offset.x, 0.25), "原始两秒滚动周期在半秒应移动四分之一纹理")
	check(scrolling.albedo_texture == texture, "滚动不能重建或替换原始纹理")
	revenant.play("Attack", true)
	revenant.advance(0.5)
	check(is_equal_approx(scrolling.uv1_offset.x, 0.5), "切换动作不能重置全局纹理时钟")
	revenant.advance(1.0)
	check(is_zero_approx(scrolling.uv1_offset.x), "全局纹理周期结束应正确回绕")
	var model := Model.new()
	root.add_child(model)
	check(model.load_model("res://art/classic/units/human/heromountainking/heromountainking.json"), "多层材质夹具必须加载")
	# 同一原始材质被不同 Geoset 使用，各自的颜色和淡出应互相隔离。
	model.material_animation.geoset_tracks = {
		0: {"Alpha": 0.5, "Flags": 2, "Color": [0.2, 0.4, 0.8]},
		3: {"Alpha": 1.0, "Flags": 2, "Color": {"LineType": 0, "GlobalSeqId": null,
			"Keys": [{"Frame": model.frame, "Vector": [0.7, 0.6, 0.1]}]}}}
	model.advance(0)
	var first: StandardMaterial3D = model.surfaces[0].material_override
	var other: StandardMaterial3D = model.surfaces[3].material_override
	check(first != other and first.next_pass != other.next_pass, "共用源材质的所有层都必须逐 Geoset 隔离")
	check(first.albedo_color.is_equal_approx(Color(0.2, 0.4, 0.8, 0.5)), "静态 RGB 颜色必须保留半透明数值")
	check(other.albedo_color.is_equal_approx(Color(0.1, 0.6, 0.7, 1)), "另一个 Geoset 不能被前者串色")
	model.material_animation.geoset_tracks[0] = {"Alpha": 0.0, "Flags": 0, "Color": [0, 0, 0]}
	model.advance(0)
	check(not model.surfaces[0].visible and model.surfaces[3].visible, "隐藏只作用于对应 Geoset")
	model.material_animation.geoset_tracks[0].Alpha = 0.3
	model.advance(0)
	check(first.albedo_color.is_equal_approx(Color(1, 1, 1, 0.3)), "恢复时必须清除旧颜色，未启用颜色位不能变黑")
	check(model.surfaces[0].visible, "淡出后的 Geoset 必须能够恢复显示")
	revenant.queue_free()
	model.queue_free()
	await process_frame
	print("经典表面动画回归，失败数：", failures)
	quit(1 if failures else 0)
