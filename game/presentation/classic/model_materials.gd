extends RefCounted
## 经典材质：读取原 PNG；按原顺序保留队色层及变身层，不用现代 PBR 高光替代旧贴图。

const ROOT := "res://art/classic/"
var model: Dictionary
var team := 1
var cache: Dictionary = {}
var textures: Dictionary = {}
var tint := Color.WHITE
var instances: Array = []

func set_texture(material: StandardMaterial3D, index: int) -> void:
	if index < 0 or index >= model.Textures.size(): return
	if not textures.has(index):
		var image := image_for(model.Textures[index])
		textures[index] = ImageTexture.create_from_image(image) if image != null else null
	material.albedo_texture = textures[index]

func texture_path(entry: Dictionary) -> String:
	var replaceable := int(entry.get("ReplaceableId", 0))
	if replaceable == 1: return ROOT + "replaceabletextures/teamcolor/teamcolor%02d.png" % team
	if replaceable == 2: return ROOT + "replaceabletextures/teamglow/teamglow%02d.png" % team
	return ROOT + str(entry.get("Image", "")).replace("\\", "/").to_lower().replace(".blp", ".png")

func image_for(entry: Dictionary) -> Image:
	var path := texture_path(entry)
	if not FileAccess.file_exists(path):
		push_error("原始模型缺少纹理：" + path)
		return null
	var result := Image.load_from_file(path)
	result.convert(Image.FORMAT_RGBA8)
	return result

func material(index: int) -> StandardMaterial3D:
	if cache.has(index):
		var copies: Array[StandardMaterial3D] = []
		for original in cache[index]:
			var copy: StandardMaterial3D = original.duplicate()
			copy.next_pass = null
			if not copies.is_empty(): copies[-1].next_pass = copy
			copies.append(copy)
		instances.append({"id": index, "passes": copies})
		return copies[0]
	var passes: Array[StandardMaterial3D] = []
	for layer in model.Materials[index].Layers:
		var result := _layer_material(layer)
		if not passes.is_empty(): passes[-1].next_pass = result
		passes.append(result)
	cache[index] = passes
	instances.append({"id": index, "passes": passes})
	return passes[0]

func _layer_material(layer: Dictionary) -> StandardMaterial3D:
	var texture_id: Variant = layer.get("TextureID")
	var result := StandardMaterial3D.new()
	result.albedo_color = tint
	if texture_id is Dictionary:
		texture_id = texture_id.Keys[0].Vector[0] if not texture_id.Keys.is_empty() else 0
	var texture_entry: Dictionary = model.Textures[int(texture_id)]
	result.texture_repeat = int(texture_entry.get("Flags", 0)) != 0
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	result.roughness = 1
	result.metallic_specular = 0
	result.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	set_texture(result, int(texture_id))
	var shading := int(layer.get("Shading", 0))
	if shading & 1: result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# MDX 位 32 为 Unfogged，64/128 才是关闭深度测试/写入。
	if shading & 32: result.disable_fog = true
	if shading & 64: result.no_depth_test = true
	if shading & 128: result.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if shading & 16: result.cull_mode = BaseMaterial3D.CULL_DISABLED
	match int(layer.get("FilterMode", 0)):
		0:
			if layer.Alpha is Dictionary:
				result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		1:
			result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			result.alpha_scissor_threshold = 0.75
		2: result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		3, 4:
			result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			result.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		5, 6:
			result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			result.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	result.albedo_color.a = float(layer.Alpha) if not layer.Alpha is Dictionary else 1.0
	return result
