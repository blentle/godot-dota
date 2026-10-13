extends SceneTree
## 双进程回归的服务端入口；正式 --server 仍未开放。

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	var port := 27883
	var server := preload("res://network/dev_server.gd").new()
	var players := 2
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="): port = int(argument.trim_prefix("--port="))
		if argument.begins_with("--delay-ms="): server.frame_delay_ms = int(argument.trim_prefix("--delay-ms="))
		if argument.begins_with("--checkpoint="): server.checkpoint.path = argument.trim_prefix("--checkpoint=")
		if argument.begins_with("--players="): players = int(argument.trim_prefix("--players="))
	if players not in [2, 4, 10] or (players != 2 and "--shared" not in OS.get_cmdline_user_args()):
		push_error("--players 仅允许共享模式的 2、4 或 10 席")
		quit(2)
		return
	if "--shared" in OS.get_cmdline_user_args():
		server.authority = preload("res://network/shared_authority.gd").new(players)
	root.add_child(server)
	if server.start(port) != OK:
		push_error("开发服务器启动失败，请检查端口、共享模式与存档诊断")
		quit(1)
		return
	print("NETWORK_SERVER_READY")
	if "--shutdown-after=20" in OS.get_cmdline_user_args():
		while server.authority.sessions.is_empty(): await process_frame
		await create_timer(20).timeout
		quit(0)
