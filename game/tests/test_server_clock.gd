extends SceneTree
## 防止服务器继承离线 30 Hz 而以每帧 1/60 秒造成半速运行。

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.physics_ticks_per_second = 30
	var server := preload("res://network/dev_server.gd").new()
	root.add_child(server)
	if server.start(0) != OK:
		push_error("测试服务器启动失败")
		quit(1)
		return
	var protocol := preload("res://network/dev_protocol.gd")
	var hello := protocol.identity()
	hello.merge({"type": "hello", "profile": "guardian"})
	var welcome: Dictionary = server.authority.receive(2, hello)
	if Engine.physics_ticks_per_second != welcome.tick_rate:
		push_error("物理帧率必须与协商模拟频率一致")
		quit(1)
		return
	server.set_physics_process(false)
	for frame in range(Engine.physics_ticks_per_second): server.authority.step()
	if absf(server.authority.session(2).world.elapsed - 1.0) > 0.0001:
		push_error("一秒物理回调数量必须推进一秒规则时间")
		quit(1)
		return
	print("服务器时钟通过：物理帧率、握手频率和规则步长一致。")
	quit(0)
