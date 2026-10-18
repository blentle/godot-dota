extends SceneTree
## 确定时间点的实机截图工具：冻结规则，只推进模型和头像的表现时间轨。

const Gallery = preload("res://presentation/classic/gallery.gd")
var scene: Control

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	scene = load("res://ui/war3/scenes/live_training.tscn").instantiate()
	root.add_child(scene)
	scene.battle.set_physics_process(false)
	var gallery := Gallery.new()
	scene.add_child(gallery)
	gallery.bind(scene)
	var prefix := "/tmp/classic-motion"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-prefix="): prefix = argument.trim_prefix("--capture-prefix=")
	var portrait: Control = scene.hud.get_node("HeroPanel/Portrait")
	portrait.set_process(false)
	for model in [scene.battle.hero.classic_model, portrait.model]:
		model.clock = 0
		model.global_clock = 0
		model.advance(0)
	portrait.camera_animation.advance()
	var failed := false
	for index in range(2):
		if index > 0:
			scene.battle.hero.classic_model.advance(0.45)
			portrait.model.advance(0.45)
			portrait.camera_animation.advance()
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s-%d.png" % [prefix, index]
		var result := root.get_texture().get_image().save_png(path)
		failed = failed or result != OK
		print("确定时间点实机截图：", path, "，结果=", result)
	scene.queue_free()
	await process_frame
	quit(1 if failed else 0)
