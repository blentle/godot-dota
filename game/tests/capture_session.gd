extends SceneTree
## 使用真实会话与规则生成选人、结算两张固定画面。

var directory := ""
var failures := 0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): directory = argument.trim_prefix("--output-dir=")
	call_deferred("_capture")

func _capture() -> void:
	if directory.is_empty():
		push_error("请指定 -- --output-dir=绝对目录")
		quit(1)
		return
	var flow := preload("res://bootstrap/client_flow.gd").new()
	root.add_child(flow)
	await _save("selection.png")
	flow.launch("ranger", "lanes")
	flow.battle.set_physics_process(false)
	var world: RefCounted = flow.battle.simulation
	world.elapsed = 184
	world.submit_buy("blade")
	world.submit_buy("vest")
	var target: RefCounted = world.combat.units.creep_1_0_1_0
	target.position = world.position + Vector3(1, 0, 0)
	target.experience_reward = 150
	world.combat.apply_damage(world.combat.player, target, 9999)
	for lane in range(3): world.combat.apply_damage(world.combat.player, world.combat.units["tower_1_%d" % lane], 9999)
	world.combat.apply_damage(world.combat.player, world.combat.units.base_1, 9999)
	await _save("result.png")
	quit(1 if failures else 0)

func _save(name: String) -> void:
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(directory.path_join(name))
	if result != OK: failures += 1
	print("会话画面：%s，结果=%s" % [name, result])
