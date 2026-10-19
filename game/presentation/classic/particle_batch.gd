extends MeshInstance3D
## 一个原始发射器一个绘制批次；使用原图集、逐顶点颜色和相机朝向，不创建粒子节点。

var source: Dictionary
var particles: Array = []
var geometry := ImmediateMesh.new()
var material := StandardMaterial3D.new()
var emitter_transform := Transform3D.IDENTITY

func build(model: Node3D, entry: Dictionary) -> void:
	source = entry
	top_level = true
	# 顶层节点切换会保留旧世界变换，必须清零，避免世界坐标被模型缩放两次。
	global_transform = Transform3D.IDENTITY
	mesh = geometry
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.texture_repeat = int(model.data.Textures[int(entry.TextureID)].get("Flags", 0)) != 0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = clampi(int(entry.PriorityPlane), -128, 127)
	material.disable_fog = (int(entry.Flags) & 262144) != 0
	match int(entry.FilterMode):
		1: material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		2, 3: material.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		4:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = 0.75
	model.materials.set_texture(material, int(entry.TextureID))
	if int(entry.ReplaceableId) in [1, 2]:
		var image: Image = model.materials.image_for({"ReplaceableId": entry.ReplaceableId})
		if image != null: material.albedo_texture = ImageTexture.create_from_image(image)
	material_override = material

func draw(camera: Camera3D) -> void:
	geometry.clear_surfaces()
	if particles.is_empty() or camera == null: return
	geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for particle in particles:
		var center: Vector3 = emitter_transform * particle.position if particle.local_space else particle.position
		var size: float = particle.radius(source)
		var right := camera.global_basis.x * size
		var up := camera.global_basis.y * size
		if int(source.Flags) & 1048576:
			# XYQuad 固定在源模型 XY 平面，不能误作始终面向相机。
			right = emitter_transform.basis.x.normalized().rotated(emitter_transform.basis.z.normalized(), particle.facing) * size
			up = emitter_transform.basis.y.normalized().rotated(emitter_transform.basis.z.normalized(), particle.facing) * size
		if int(source.FrameFlags) & 1:
			_quad([center+right+up, center-right+up, center-right-up, center+right-up], particle, false)
		if int(source.FrameFlags) & 2:
			var speed: Vector3 = emitter_transform.basis * particle.velocity if particle.local_space else particle.velocity
			var end := center - speed * float(source.TailLength)
			var side := camera.global_basis.z.cross(speed).normalized() * size
			if side.length_squared() < 0.00001: side = right
			_quad([center-side, end-side, end+side, center+side], particle, true)
	geometry.surface_end()

func _quad(points: Array, particle: RefCounted, tail: bool) -> void:
	var cell: int = particle.cell(source, tail)
	var columns := maxi(1, int(source.Columns))
	var rows := maxi(1, int(source.Rows))
	# 已按队伍取出单张原始队色图，不再按原组合图集切格。
	if int(source.ReplaceableId) in [1, 2]:
		cell = 0
		columns = 1
		rows = 1
	var left := float(cell % columns) / columns
	var top := floorf(float(cell) / columns) / rows
	var uv := [Vector2(left+1.0/columns, top), Vector2(left, top),
		Vector2(left, top+1.0/rows), Vector2(left+1.0/columns, top+1.0/rows)]
	for index in [0, 1, 2, 0, 2, 3]:
		geometry.surface_set_color(particle.color(source))
		geometry.surface_set_uv(uv[index])
		geometry.surface_add_vertex(points[index])
