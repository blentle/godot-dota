extends Node
## 共用入口：校验模式只检查清单，默认打开离线训练场景。

const MANIFEST_PATH := "res://content/6.83d/manifest.json"

func _ready() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not manifest is Dictionary:
		push_error("Missing or invalid content manifest")
		get_tree().quit(1)
		return
	var engine := Engine.get_version_info()
	var actual := "%s.%s.%s" % [engine.major, engine.minor, engine.patch]
	if actual != manifest.get("engine_version", ""):
		push_error("Engine mismatch: expected %s, got %s" % [manifest.get("engine_version"), actual])
		get_tree().quit(1)
		return
	if manifest.get("ruleset_id") != "dota-6.83d" or manifest.get("players_per_match") != 10:
		push_error("Invalid ruleset identity or player count")
		get_tree().quit(1)
		return
	var role := "server" if "--server" in OS.get_cmdline_user_args() else "client"
	print("%s bootstrap: engine=%s ruleset=%s content=%s" % [role, actual, manifest.ruleset_id, manifest.status])
	if "--validate-content" in OS.get_cmdline_user_args():
		get_tree().quit(0)
	elif role == "server":
		push_error("Dedicated server is not implemented yet.")
		get_tree().quit(2)
	else:
		var scene := preload("res://world/battlefield.gd").new()
		add_child(scene)
