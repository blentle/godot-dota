extends SceneTree
## 双进程回归的服务端入口；正式 --server 仍未开放。

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	var port := 27883
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="): port = int(argument.trim_prefix("--port="))
	var server := preload("res://network/dev_server.gd").new()
	root.add_child(server)
	if server.start(port) != OK:
		push_error("开发服务器端口不可用")
		quit(1)
		return
	print("NETWORK_SERVER_READY")
	if "--shutdown-after=20" in OS.get_cmdline_user_args():
		while server.authority.owner == 0: await process_frame
		await create_timer(20).timeout
		quit(0)
