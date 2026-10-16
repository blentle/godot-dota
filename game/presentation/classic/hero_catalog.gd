extends RefCounted
## 外观目录只描述地图资源映射；不提供英雄技能、生命或金币等规则状态。

const ROOT := "res://art/classic/"
static var heroes: Array = []

static func entries() -> Array:
	if heroes.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "hero-catalog.json"))
		heroes = data.heroes
	return heroes

static func find(code: String) -> Dictionary:
	for hero in entries():
		if hero.id == code: return hero
	return {}

static func model_path(hero: Dictionary) -> String:
	return ROOT + str(hero.model).replace(".mdx", ".json")

static func icon_path(hero: Dictionary) -> String:
	return ROOT + str(hero.icon).replace(".blp", ".png")
