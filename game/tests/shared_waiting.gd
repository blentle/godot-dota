extends SceneTree
## 新局单客户端等待超过旧的八秒装载超时；确认心跳保持且世界没有提前运行。

var flow: Node
var started := Time.get_ticks_msec()
var waiting_since := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	flow = preload("res://bootstrap/network_flow.gd").new()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="): flow.port = int(argument.trim_prefix("--port="))
	root.add_child(flow)

func _process(_delta: float) -> bool:
	if flow == null: return false
	if flow.phase == "failed" or Time.get_ticks_msec() - started > 15000:
		push_error("新局等待失败：" + flow.phase)
		quit(1)
	if flow.phase == "waiting":
		if waiting_since == 0: waiting_since = Time.get_ticks_msec()
		if Time.get_ticks_msec() - waiting_since > 9000:
			if flow.world.elapsed != 0 or flow.world.combat.gold != 300:
				push_error("等待期间世界已推进")
				quit(1)
			else:
				print("SHARED_WAITING_PASS")
				flow.client.close()
				quit(0)
	return false
