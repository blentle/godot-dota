extends MeshInstance3D
## 原始飘带绘制：连接相邻世界空间截面，按材质和原图集展开，禁止跨断带连接。

const Materials = preload("res://presentation/classic/model_materials.gd")
var source: Dictionary
var model: Node3D
var sections: Array = []
var geometry := ImmediateMesh.new()
var materials := Materials.new()
var strips := 0

func build(view: Node3D, entry: Dictionary) -> void:
	model = view
	source = entry
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = geometry
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	materials.model = model.data
	materials.team = model.materials.team
	materials.tint = model.materials.tint
	material_override = materials.material(int(source.MaterialID))
	for pass_material in materials.cache[int(source.MaterialID)]:
		pass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		pass_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED

func draw() -> void:
	geometry.clear_surfaces()
	strips = 0
	if sections.size() < 2: return
	var connected := false
	for index in range(sections.size()-1):
		var a: Dictionary = sections[index]
		var b: Dictionary = sections[index+1]
		if a.chain == b.chain and (not a.above.is_equal_approx(b.above) or not a.below.is_equal_approx(b.below)):
			connected = true
			break
	if not connected: return
	var color: Array = source.Color
	var alpha := float(model.sample(source.Alpha, 1.0))
	var tint: Color = Color(color[0], color[1], color[2], alpha) * model.materials.tint
	var layers: Array = model.data.Materials[int(source.MaterialID)].Layers
	var passes: Array = materials.cache[int(source.MaterialID)]
	for index in range(passes.size()):
		var pass_material: StandardMaterial3D = passes[index]
		pass_material.albedo_color = tint
		pass_material.albedo_color.a *= float(model.sample(layers[index].get("Alpha"), 1.0))
		if layers[index].TextureID is Dictionary:
			materials.set_texture(pass_material, int(model.sample(layers[index].TextureID, 0)))
		model.material_animation._apply_uv(pass_material, layers[index])
	geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(sections.size()-1):
		var a: Dictionary = sections[index]
		var b: Dictionary = sections[index+1]
		if a.chain != b.chain: continue
		if a.above.is_equal_approx(b.above) and a.below.is_equal_approx(b.below): continue
		var points := [a.above, a.below, b.below, b.above]
		var uv := [_uv(a, false), _uv(a, true), _uv(b, true), _uv(b, false)]
		for corner in [0, 1, 2, 0, 2, 3]:
			geometry.surface_set_uv(uv[corner])
			geometry.surface_add_vertex(points[corner])
		strips += 1
	geometry.surface_end()

func _uv(section: Dictionary, below: bool) -> Vector2:
	var columns := maxi(1, int(source.Columns))
	var rows := maxi(1, int(source.Rows))
	var slot := clampi(int(model.sample(source.TextureSlot, 0)), 0, columns*rows-1)
	var life := maxf(0.0001, float(source.LifeSpan))
	return Vector2((slot % columns + clampf(section.age/life, 0, 1))/columns,
		(floorf(float(slot)/columns) + (1 if below else 0))/rows)
