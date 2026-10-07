extends RefCounted
## 本机开发客户端只保留服务器快照，不创建或推进训练规则世界。

signal received(message: Dictionary)
var peer := ENetMultiplayerPeer.new()
var latest: Dictionary = {}
var started := false

func start(port: int) -> Error:
	var error := peer.create_client("127.0.0.1", port)
	started = error == OK
	return error

func poll() -> void:
	if not started: return
	peer.poll()
	while peer.get_available_packet_count() > 0:
		var sender := peer.get_packet_peer()
		var packet := peer.get_packet()
		if sender != 1 or packet.size() > 262144: continue
		var parser := JSON.new()
		if parser.parse(packet.get_string_from_utf8()) != OK or not parser.data is Dictionary: continue
		var message: Dictionary = parser.data
		if message.get("type") == "snapshot":
			if message.get("tick", -1) <= latest.get("tick", -1): continue
			latest = message.duplicate(true)
		received.emit(message)

func send(message: Dictionary) -> Error:
	if not started or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED: return ERR_UNAVAILABLE
	peer.set_target_peer(1)
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	return peer.put_packet(JSON.stringify(message).to_utf8_buffer())

func close() -> void:
	if started: peer.close()
	started = false
	latest = {}
