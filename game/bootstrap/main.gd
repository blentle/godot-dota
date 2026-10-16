extends Node
## 共用入口：校验模式只检查清单，默认打开当前经典美术训练场。

const MANIFEST_PATH := "res://content/6.83d/manifest.json"

func _ready() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not manifest is Dictionary:
		push_error("内容清单缺失或无效")
		get_tree().quit(1)
		return
	var engine := Engine.get_version_info()
	var actual := "%s.%s.%s" % [engine.major, engine.minor, engine.patch]
	if actual != manifest.get("engine_version", ""):
		push_error("引擎版本不匹配：要求 %s，实际 %s" % [manifest.get("engine_version"), actual])
		get_tree().quit(1)
		return
	if manifest.get("ruleset_id") != "dota-6.83d" or manifest.get("players_per_match") != 10:
		push_error("规则版本或玩家数量无效")
		get_tree().quit(1)
		return
	var role := "server" if "--server" in OS.get_cmdline_user_args() else "client"
	print("%s bootstrap: engine=%s ruleset=%s content=%s" % [role, actual, manifest.ruleset_id, manifest.status])
	if "--validate-content" in OS.get_cmdline_user_args():
		get_tree().quit(0)
	elif role == "server":
		push_error("正式专用服务器尚未实现。")
		get_tree().quit(2)
	elif OS.get_cmdline_user_args().is_empty() or "--war3-training" in OS.get_cmdline_user_args() or "--classic-gallery" in OS.get_cmdline_user_args():
		var training := preload("res://ui/war3/scenes/live_training.tscn").instantiate()
		add_child(training)
		if "--classic-gallery" in OS.get_cmdline_user_args():
			var gallery := preload("res://presentation/classic/gallery.gd").new()
			training.add_child(gallery)
			gallery.bind(training)
	elif "--war3-hud" in OS.get_cmdline_user_args():
		add_child(preload("res://ui/war3/scenes/preview.tscn").instantiate())
	else:
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--connect-local="):
				var network := preload("res://bootstrap/network_flow.gd").new()
				network.port = int(argument.trim_prefix("--connect-local="))
				add_child(network)
				return
		var scene := preload("res://bootstrap/client_flow.gd").new()
		add_child(scene)
