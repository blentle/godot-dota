extends SceneTree
## 实际 ENet 客户端进程，以服务器快照验证扣费和移动，不运行本地模拟。

const Protocol = preload("res://network/dev_protocol.gd")
var client := preload("res://network/dev_client.gd").new()
var phase := "connecting"
var started := Time.get_ticks_msec()
var port := 27883
var initial_position: Array = []
var last_tick := -1
var ticks_seen := 0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="): port = int(argument.trim_prefix("--port="))
	client.received.connect(_receive)
	if client.start(port) != OK: _fail("客户端创建失败")

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started > 12000:
		_fail("网络测试超时：" + phase)
		return false
	client.poll()
	if phase == "connecting" and client.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		phase = "bad_version"
		var hello := Protocol.identity()
		hello.merge({"type": "hello", "profile": "guardian"})
		hello.version = 99
		client.send(hello)
	return false

func _receive(message: Dictionary) -> void:
	if message.get("type") == "snapshot":
		_snapshot(message)
		return
	match phase:
		"bad_version":
			if message.get("code") != "VERSION_MISMATCH": return _fail("错误版本未被拒绝")
			phase = "hello"
			var hello := Protocol.identity()
			hello.merge({"type": "hello", "profile": "guardian"})
			client.send(hello)
		"hello":
			if message.get("type") != "welcome": return _fail("合法握手失败")
			phase = "buy"
			_send(1, "buy", "blade")
		"buy":
			if not message.get("ok", false): return _fail("远程购买失败")
			phase = "duplicate"
			_send(1, "buy", "blade")
		"duplicate":
			if not message.get("ok", false) or message.get("sequence") != 1: return _fail("重复命令未确认")
			phase = "inventory"
		"move":
			if not message.get("ok", false): return _fail("远程移动失败")
			phase = "moving"

func _snapshot(message: Dictionary) -> void:
	if message.tick <= last_tick: return _fail("快照时间倒退")
	last_tick = int(message.tick)
	ticks_seen += 1
	if phase == "bad_version": return _fail("握手前泄漏世界")
	if phase == "inventory" and message.ack == 1:
		var price: int = preload("res://simulation/item_catalog.gd").ITEMS.blade.price
		if message.inventory.count("blade") != 1 or absf(float(message.gold) - (300 - price + floorf(float(message.tick) / 60.0))) > 1:
			return _fail("重复购买改变了库存或金币")
		for unit in message.units:
			if unit.id == "player": initial_position = unit.position
		if initial_position.is_empty(): return _fail("快照缺少玩家")
		phase = "move"
		_send(2, "move", [initial_position[0] + 4, initial_position[1]])
	elif phase == "moving" and message.ack == 2:
		for unit in message.units:
			if unit.id == "player" and float(unit.position[0]) > float(initial_position[0]) + 1.0:
				print("NETWORK_CLIENT_PASS：远程握手、重复交易、权威移动与连续快照，快照数=%d" % ticks_seen)
				client.close()
				quit(0)

func _send(sequence: int, command: String, target: Variant) -> void:
	client.send({"type": "command", "match": Protocol.MATCH_ID, "sequence": sequence, "command": command, "target": target})

func _fail(reason: String) -> void:
	push_error(reason)
	client.close()
	quit(1)
