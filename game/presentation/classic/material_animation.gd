extends RefCounted
## 原始材质时间轨：逐 Geoset 合成颜色和透明度，避免共用材质相互污染。

var model: Node3D
var geoset_tracks: Dictionary = {}

func bind(view: Node3D) -> void:
	model = view
	for animation in model.data.GeosetAnims:
		if animation.get("GeosetId") != null:
			geoset_tracks[int(animation.GeosetId)] = animation

func advance() -> void:
	for index in range(model.materials.instances.size()):
		var instance: Dictionary = model.materials.instances[index]
		var animation: Dictionary = geoset_tracks.get(index, {})
		var alpha := float(model.sample(animation.get("Alpha"), 1.0))
		var tint: Color = model.materials.tint
		# MDX 静态颜色为 RGB，颜色时间轨为 BGR；未启用颜色位时忽略字段。
		if int(animation.get("Flags", 0)) & 2:
			var value: Variant = animation.get("Color")
			var rgb: Vector3 = sample_vector(value, Vector3.ONE)
			if value is Dictionary: rgb = Vector3(rgb.z, rgb.y, rgb.x)
			tint *= Color(rgb.x, rgb.y, rgb.z)
		model.surfaces[index].visible = alpha > 0.01
		var layers: Array = model.data.Materials[instance.id].Layers
		for at in range(layers.size()):
			var layer: Dictionary = layers[at]
			var material: StandardMaterial3D = instance.passes[at]
			material.albedo_color = Color(tint.r, tint.g, tint.b,
				alpha * float(model.sample(layer.get("Alpha"), 1.0)))
			if layer.TextureID is Dictionary:
				model.materials.set_texture(material, int(model.sample(layer.TextureID, 0)))
			_apply_uv(material, layer)

func sample_vector(track: Variant, fallback: Vector3) -> Vector3:
	# 静态三元数组与时间轨都保留源值，不把它们误作标量。
	if track is Array: return Vector3(track[0], track[1], track[2])
	return model.sample(track, fallback)

func _apply_uv(material: StandardMaterial3D, layer: Dictionary) -> void:
	var id: Variant = layer.get("TVertexAnimId")
	if id == null: return
	if int(id) < 0 or int(id) >= model.data.TextureAnims.size(): return
	var track: Dictionary = model.data.TextureAnims[int(id)]
	var offset: Vector3 = sample_vector(track.get("Translation"), Vector3.ZERO)
	var scale: Vector3 = sample_vector(track.get("Scaling"), Vector3.ONE)
	# 纹理围绕 0.5 缩放；当前地图模型的 21 组 UV 时间轨均为平移。
	material.uv1_scale = Vector3(scale.x, scale.y, 1)
	material.uv1_offset = Vector3(offset.x * scale.x + (1-scale.x)*0.5,
		offset.y * scale.y + (1-scale.y)*0.5, 0)
