extends SceneTree
## 校对模式只能切换表现资源；原始地图自带头像相机的英雄同样必须可切换。

const Gallery = preload("res://presentation/classic/gallery.gd")
const Catalog = preload("res://presentation/classic/hero_catalog.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var scene = load("res://ui/war3/scenes/live_training.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.battle.set_physics_process(false)
	var actor: RefCounted = scene.battle.simulation.combat.player
	var before: Array = [actor.hp, actor.mana, actor.damage, actor.profile_id]
	check(Catalog.find("Hmbr").display_name == "Zeus", "宙斯默认名应来自出现七次的 Zeus，而不是去重后的首个纪念名")
	check(Catalog.find("Nfir").display_name == "Nevermore", "影魔默认名应保留原始专名频次")
	var gallery := Gallery.new()
	scene.add_child(gallery)
	gallery.bind(scene)
	for code in ["Hjai", "U00F", "N0HP", "Hmbr"]:
		for index in range(Catalog.entries().size()):
			if Catalog.entries()[index].id == code: gallery.select(index)
		check(scene.hud.visual_hero.id == code, "目录切换必须同步 HUD 外观")
		check(scene.hud.get_node("HeroPanel/Portrait").character == code, "动态头像必须切换到相同英雄")
		check(scene.battle.hero.classic_model.data.Version == 800, "必须读取原始经典模型")
		var entry: Dictionary = scene.hud.visual_hero
		check(scene.hud.get_node("HeroPanel/HeroName").text == entry.display_name, "姓名行应使用地图专名")
		check(scene.hud.get_node("HeroPanel/Class").text == "第%d级 %s" % [actor.level, entry.name], "职业行应保留等级和称号，不能重复专名")
		check(before == [actor.hp, actor.mana, actor.damage, actor.profile_id], "美术切换不能改写训练规则")
		await process_frame
	scene.queue_free()
	await process_frame
	print("经典外观切换回归，失败数：", failures)
	quit(1 if failures else 0)
