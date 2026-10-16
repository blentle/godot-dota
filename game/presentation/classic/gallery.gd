extends Node
## 独立美术校对模式：切换地图英雄外观，训练规则保持不变，避免冒充英雄玩法。

const Catalog = preload("res://presentation/classic/hero_catalog.gd")
var scene: Control
var index := 0

func bind(target: Control) -> void:
	scene = target
	for at in range(Catalog.entries().size()):
		if Catalog.entries()[at].id == "Hmbr": index = at
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--classic-hero="):
			for at in range(Catalog.entries().size()):
				if Catalog.entries()[at].id == argument.trim_prefix("--classic-hero="): index = at
	select(index)

func select(at: int) -> void:
	index = wrapi(at, 0, Catalog.entries().size())
	var entry: Dictionary = Catalog.entries()[index]
	var view: Node3D = scene.battle.hero
	view.visual_resource = Catalog.model_path(entry)
	view.visual_tags = PackedStringArray(entry.animation_tags)
	view.visual_scale = float(entry.model_scale)
	view.visual_color = Color8(int(entry.color[0]), int(entry.color[1]), int(entry.color[2]))
	view.replace_classic_model()
	scene.hud.visual_hero = entry
	scene.get_node("Interface/Notice").text = "外观校对 %d/112 · %s · PageUp/PageDown 切换 · 训练规则未替换" % [index+1, entry.name]
	scene._refresh()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		select(index + (1 if event.physical_keycode == KEY_PAGEDOWN else -1))
		get_viewport().set_input_as_handled()
