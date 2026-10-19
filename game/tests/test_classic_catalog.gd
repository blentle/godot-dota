extends SceneTree
## 全英雄外观加载冒烟：只证明网格、纹理和动画可读，不代替逐英雄实机比对。

const Model = preload("res://presentation/classic/model_view.gd")
const Catalog = preload("res://presentation/classic/hero_catalog.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var paths: Dictionary = {}
	for hero in Catalog.entries():
		paths[Catalog.model_path(hero)] = hero.animation_tags
		var portrait := Catalog.model_path(hero).replace(".json", "_portrait.json")
		if FileAccess.file_exists(portrait): paths[portrait] = hero.animation_tags
	var count := 0
	for path in paths:
		var model := Model.new()
		root.add_child(model)
		if not model.load_model(path): failures += 1
		else:
			if model.particles == null or model.particles.emitters.size() != model.data.ParticleEmitters2.size(): failures += 1
			if model.ribbons == null or model.ribbons.emitters.size() != model.data.RibbonEmitters.size(): failures += 1
			if model.model_particles == null or model.model_particles.emitters.size() != model.data.ParticleEmitters.size(): failures += 1
			model.animation_tags = PackedStringArray(paths[path])
			for action in ["Stand", "Walk", "Attack", "Spell", "Death", "Portrait"]:
				model.play(action, true)
				model.advance(0.13)
			if model.surfaces.is_empty(): failures += 1
		model.queue_free()
		await process_frame
		count += 1
	print("全英雄外观加载冒烟，模型数：%d，失败数：%d" % [count, failures])
	quit(1 if failures else 0)
