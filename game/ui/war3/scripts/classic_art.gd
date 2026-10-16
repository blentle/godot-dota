extends RefCounted
## 原始美术资源入口；缓存 PNG 纹理，不把测试图标混入经典皮肤。

const ROOT := "res://art/classic/"
static var cache: Dictionary = {}

static func texture(path: String) -> Texture2D:
	var full := ROOT + path
	if cache.has(full): return cache[full]
	if not FileAccess.file_exists(full): return null
	var image := Image.load_from_file(full)
	var result := ImageTexture.create_from_image(image)
	cache[full] = result
	return result

static func icon(name: String, disabled := false) -> Texture2D:
	if name.is_empty(): return null
	var folder := "commandbuttonsdisabled/dis" if disabled else "commandbuttons/"
	return texture("replaceabletextures/" + folder + name + ".png")

static func highlight() -> Texture2D:
	return texture("ui/widgets/console/human/commandbutton/human-activebutton.png")

static func model_name(profile: String) -> String:
	return "heromountainking" if profile == "guardian" else "jaina"

static func region(path: String, width: int, height: int) -> Texture2D:
	var source := texture(path)
	if source == null: return null
	var result := AtlasTexture.new()
	result.atlas = source
	result.region = Rect2(0, 0, width, height)
	return result

static func menu(state: int, race := "nightelf") -> Texture2D:
	return region("button-%s-%s.png" % [race, ["normal", "hover", "disabled"][state]], 85, 22)

static func item_name(id: String) -> String:
	return {"blade": "btnattack", "vest": "btnleatherupgradeone", "charm": "btnperiapt", "boots": "btnbootsofspeed"}.get(id, "")
